import Contacts
import EventKit
import Foundation

struct DeviceSyncError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}

/// Android's `DeviceDataGateway`: the calendars and contacts every account
/// syncs to this iPhone, and the changes the server queued for them.
final class DeviceDataGateway {
  let eventStore = EKEventStore()
  let contactStore = CNContactStore()

  private static let iso: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static func grantedKinds() -> [String] {
    var kinds: [String] = []
    let calendarStatus = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *) {
      if calendarStatus == .fullAccess { kinds.append("calendar") }
    } else if calendarStatus == .authorized {
      kinds.append("calendar")
    }
    if CNContactStore.authorizationStatus(for: .contacts) == .authorized { kinds.append("contacts") }
    return kinds
  }

  func requestAccess(_ kinds: [String]) async {
    if kinds.contains("calendar") {
      if #available(iOS 17.0, *) {
        _ = try? await eventStore.requestFullAccessToEvents()
      } else {
        _ = try? await eventStore.requestAccess(to: .event)
      }
    }
    if kinds.contains("contacts") {
      _ = try? await contactStore.requestAccess(for: .contacts)
    }
  }

  func calendars() -> [[String: Any]] {
    let primary = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
    return eventStore.calendars(for: .event).map { calendar in
      [
        "id": calendar.calendarIdentifier,
        "name": calendar.title,
        "account": calendar.source?.title ?? "",
        "writable": calendar.allowsContentModifications,
        "primary": calendar.calendarIdentifier == primary,
      ]
    }
  }

  /// One entry per occurrence, so repeating events need no expanding later.
  func events(from start: Date, to end: Date) -> [[String: Any]] {
    let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
    return eventStore.events(matching: predicate).map { event in
      let eventId = event.eventIdentifier ?? ""
      return [
        "key": "\(eventId):\(Int(event.startDate.timeIntervalSince1970))",
        "eventId": eventId,
        "calendarId": event.calendar.calendarIdentifier,
        "title": event.title ?? "",
        "start": Self.iso.string(from: event.startDate),
        "end": Self.iso.string(from: event.endDate),
        "allDay": event.isAllDay,
        "location": event.location ?? "",
        "notes": String((event.notes ?? "").prefix(2000)),
        "attendees": (event.attendees ?? []).map { attendee in
          attendee.name ?? attendee.url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
        },
      ]
    }
  }

  func contacts() throws -> [[String: Any]] {
    let keys: [CNKeyDescriptor] = [
      CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
      CNContactEmailAddressesKey as CNKeyDescriptor,
      CNContactPhoneNumbersKey as CNKeyDescriptor,
      CNContactOrganizationNameKey as CNKeyDescriptor,
    ]
    var rows: [[String: Any]] = []
    try contactStore.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { contact, _ in
      let name = CNContactFormatter.string(from: contact, style: .fullName) ?? contact.organizationName
      guard !name.isEmpty else { return }
      rows.append([
        "key": contact.identifier,
        "name": name,
        "emails": contact.emailAddresses.map { $0.value as String },
        "phones": contact.phoneNumbers.map { $0.value.stringValue },
        "organization": contact.organizationName,
      ])
    }
    return rows
  }

  /// Makes one change the server queued and returns what to report back.
  func apply(_ action: String, _ payload: [String: Any]) throws -> [String: Any] {
    switch action {
    case "create_event":
      let event = EKEvent(eventStore: eventStore)
      event.calendar = try calendar(payload["calendarId"] as? String)
      try fill(event, payload)
      if event.endDate == nil { event.endDate = event.startDate }
      try eventStore.save(event, span: .thisEvent)
      return ["eventId": event.eventIdentifier ?? "", "calendarId": event.calendar.calendarIdentifier]
    case "update_event":
      let event = try existingEvent(payload)
      try fill(event, payload)
      // Matches Android, where the change applies to the whole series.
      try eventStore.save(event, span: .futureEvents)
      return ["eventId": event.eventIdentifier ?? ""]
    case "delete_event":
      let event = try existingEvent(payload)
      try eventStore.remove(event, span: .futureEvents)
      return ["eventId": payload["eventId"] as? String ?? "", "deleted": true]
    case "create_contact":
      let contact = CNMutableContact()
      contact.givenName = payload["name"] as? String ?? ""
      if let email = payload["email"] as? String, !email.isEmpty {
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
      }
      if let phone = payload["phone"] as? String, !phone.isEmpty {
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
      }
      if let organization = payload["organization"] as? String { contact.organizationName = organization }
      let request = CNSaveRequest()
      request.add(contact, toContainerWithIdentifier: nil)
      try contactStore.execute(request)
      return ["name": contact.givenName, "created": true]
    default:
      throw DeviceSyncError(message: "This app version cannot \(action).")
    }
  }

  private func calendar(_ id: String?) throws -> EKCalendar {
    if let id, !id.isEmpty {
      guard let calendar = eventStore.calendar(withIdentifier: id) else {
        throw DeviceSyncError(message: "That calendar is no longer on the phone.")
      }
      return calendar
    }
    guard let calendar = eventStore.defaultCalendarForNewEvents else {
      throw DeviceSyncError(message: "No calendar on this phone can be written to.")
    }
    return calendar
  }

  private func existingEvent(_ payload: [String: Any]) throws -> EKEvent {
    guard let id = payload["eventId"] as? String, let event = eventStore.event(withIdentifier: id) else {
      throw DeviceSyncError(message: "That event is no longer on the phone.")
    }
    return event
  }

  private func fill(_ event: EKEvent, _ payload: [String: Any]) throws {
    if let title = payload["title"] as? String { event.title = title }
    if let location = payload["location"] as? String { event.location = location }
    if let notes = payload["notes"] as? String { event.notes = notes }
    if let allDay = payload["allDay"] as? Bool { event.isAllDay = allDay }
    if let start = try date(payload, "start") { event.startDate = start }
    if let end = try date(payload, "end") { event.endDate = end }
  }

  private func date(_ payload: [String: Any], _ key: String) throws -> Date? {
    guard let raw = payload[key] as? String else { return nil }
    guard let date = Self.iso.date(from: raw) else {
      throw DeviceSyncError(message: "\(key) must be an ISO datetime.")
    }
    return date
  }
}
