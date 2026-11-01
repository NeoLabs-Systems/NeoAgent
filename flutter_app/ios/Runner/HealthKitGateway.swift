import Foundation
import HealthKit

/// Reads steps, heart rate, sleep, workouts and weight from HealthKit into
/// the batch the server's `/api/mobile/health/sync` takes, record for record
/// the shape Android's `HealthConnectGateway` sends.
final class HealthKitGateway {
  static let store = HKHealthStore()

  static let sampleTypes: [HKSampleType] = [
    HKQuantityType(.stepCount),
    HKQuantityType(.heartRate),
    HKCategoryType(.sleepAnalysis),
    HKObjectType.workoutType(),
    HKQuantityType(.bodyMass),
  ]

  /// Sleep samples closer than this belong to the same night.
  private static let sleepGap: TimeInterval = 60 * 60

  private let isoFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

  /// HealthKit never says whether reading was allowed, only whether the
  /// user has been asked; once asked, a denied type just returns nothing.
  static func hasAsked() async -> Bool {
    let status = try? await store.statusForAuthorizationRequest(toShare: [], read: Set(sampleTypes))
    return status == .unnecessary
  }

  static func requestAuthorization() async throws {
    try await store.requestAuthorization(toShare: [], read: Set(sampleTypes))
  }

  func collectBatch(windowStart: Date, windowEnd: Date) async throws -> [String: Any] {
    let range = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd)
    let steps = try await samples(HKQuantityType(.stepCount), range) as [HKQuantitySample]
    let heartRates = try await samples(HKQuantityType(.heartRate), range) as [HKQuantitySample]
    let sleep = try await samples(HKCategoryType(.sleepAnalysis), range) as [HKCategorySample]
    let workouts = try await samples(.workoutType(), range) as [HKWorkout]
    let weights = try await samples(HKQuantityType(.bodyMass), range) as [HKQuantitySample]

    let bpmUnit = HKUnit.count().unitDivided(by: .minute())
    let sleepSessions = Self.nights(from: sleep)
    let bpm = heartRates.map { $0.quantity.doubleValue(for: bpmUnit) }
    let sleepMinutes = sleepSessions.reduce(0) { $0 + minutes($1.start, $1.end) }
    let exerciseMinutes = workouts.reduce(0) { $0 + minutes($1.startDate, $1.endDate) }
    let latestWeight = weights.max { $0.endDate < $1.endDate }?.quantity.doubleValue(for: .gramUnit(with: .kilo))

    var records: [[String: Any]] = []
    records += steps.map(stepRecord)
    records += heartRates.map { heartRateRecord($0, bpm: $0.quantity.doubleValue(for: bpmUnit)) }
    records += sleepSessions.map(sleepRecord)
    records += workouts.map(workoutRecord)
    records += weights.map(weightRecord)

    return [
      "source": "ios-healthkit",
      "provider": "com.apple.health",
      "windowStart": isoFormatter.string(from: windowStart),
      "windowEnd": isoFormatter.string(from: windowEnd),
      "summary": [
        "stepsTotal": steps.reduce(0) { $0 + Int($1.quantity.doubleValue(for: .count())) },
        // Each HealthKit heart-rate sample is one reading.
        "heartRateRecordCount": heartRates.count,
        "heartRateSampleCount": heartRates.count,
        "heartRateAvgBpm": bpm.isEmpty ? NSNull() : bpm.reduce(0, +) / Double(bpm.count),
        "sleepSessionCount": sleepSessions.count,
        "sleepMinutes": sleepMinutes,
        "exerciseSessionCount": workouts.count,
        "exerciseMinutes": exerciseMinutes,
        "weightRecordCount": weights.count,
        "latestWeightKg": latestWeight ?? NSNull(),
      ] as [String: Any],
      "records": records,
    ]
  }

  private func samples<T: HKSample>(_ type: HKSampleType, _ predicate: NSPredicate) async throws -> [T] {
    try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(
        sampleType: type,
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
      ) { _, results, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: results as? [T] ?? [])
        }
      }
      Self.store.execute(query)
    }
  }

  // MARK: Records

  private func record(
    _ metricType: String,
    _ sample: HKSample,
    id: String? = nil,
    start: Date? = nil,
    end: Date?? = nil,
    value: Double?,
    text: String? = nil,
    unit: String,
    payload: [String: Any]
  ) -> [String: Any] {
    let startDate = start ?? sample.startDate
    let endDate = end ?? sample.endDate
    let device = sample.device.map { [$0.manufacturer, $0.model].compactMap { $0 }.joined(separator: " ") }
    return [
      "metricType": metricType,
      "recordId": id ?? sample.uuid.uuidString,
      "startTime": isoFormatter.string(from: startDate),
      "endTime": endDate.map(isoFormatter.string(from:)) ?? NSNull(),
      "recordedAt": isoFormatter.string(from: endDate ?? startDate),
      "numericValue": value ?? NSNull(),
      "textValue": text ?? NSNull(),
      "unit": unit,
      "sourceAppId": sample.sourceRevision.source.bundleIdentifier,
      "sourceDevice": device.flatMap { $0.isEmpty ? nil : $0 } ?? NSNull(),
      // HealthKit keeps no modification time; a changed sample gets a new id.
      "lastModifiedTime": NSNull(),
      "payload": payload,
    ]
  }

  private func stepRecord(_ sample: HKQuantitySample) -> [String: Any] {
    let count = Int(sample.quantity.doubleValue(for: .count()))
    return record("steps", sample, value: Double(count), unit: "steps", payload: ["count": count])
  }

  private func heartRateRecord(_ sample: HKQuantitySample, bpm: Double) -> [String: Any] {
    record(
      "heart_rate", sample, value: bpm, text: "1 samples", unit: "bpm",
      payload: [
        "sampleCount": 1,
        "minBpm": bpm,
        "maxBpm": bpm,
        "avgBpm": bpm,
        "samples": [["time": isoFormatter.string(from: sample.endDate), "beatsPerMinute": bpm]],
      ]
    )
  }

  private func sleepRecord(_ night: SleepNight) -> [String: Any] {
    let first = night.stages[0]
    return record(
      "sleep_session", first, start: night.start, end: night.end,
      value: Double(minutes(night.start, night.end)), unit: "minutes",
      payload: [
        "title": NSNull(),
        "notes": NSNull(),
        "stageCount": night.stages.count,
        "stages": night.stages.map {
          [
            "startTime": isoFormatter.string(from: $0.startDate),
            "endTime": isoFormatter.string(from: $0.endDate),
            "stage": $0.value,
          ] as [String: Any]
        },
      ]
    )
  }

  private func workoutRecord(_ workout: HKWorkout) -> [String: Any] {
    let type = Int(workout.workoutActivityType.rawValue)
    return record(
      "exercise_session", workout, value: Double(minutes(workout.startDate, workout.endDate)),
      text: "exercise:\(type)", unit: "minutes",
      payload: ["exerciseType": type, "title": NSNull(), "notes": NSNull()]
    )
  }

  private func weightRecord(_ sample: HKQuantitySample) -> [String: Any] {
    let kilograms = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
    return record(
      "weight", sample, end: .some(nil), value: kilograms, unit: "kg",
      payload: ["kilograms": kilograms]
    )
  }

  private func minutes(_ start: Date, _ end: Date) -> Int {
    Int(end.timeIntervalSince(start) / 60)
  }

  // MARK: Sleep

  struct SleepNight {
    let start: Date
    let end: Date
    let stages: [HKCategorySample]
  }

  /// HealthKit stores sleep as stage segments; Health Connect, which the
  /// server's records follow, as sessions with stages. Segments of one night
  /// are joined, with time merely in bed left out.
  private static func nights(from samples: [HKCategorySample]) -> [SleepNight] {
    let inBed = HKCategoryValueSleepAnalysis.inBed.rawValue
    var nights: [SleepNight] = []
    var stages: [HKCategorySample] = []
    var end = Date.distantPast
    for sample in samples where sample.value != inBed {
      if !stages.isEmpty, sample.startDate.timeIntervalSince(end) > sleepGap {
        nights.append(SleepNight(start: stages[0].startDate, end: end, stages: stages))
        stages = []
      }
      stages.append(sample)
      end = max(end, sample.endDate)
    }
    if !stages.isEmpty {
      nights.append(SleepNight(start: stages[0].startDate, end: end, stages: stages))
    }
    return nights
  }
}
