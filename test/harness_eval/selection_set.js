'use strict';

// Requests with the tools that could do them, in the two languages the owner
// actually uses. It measures one thing: was a tool that can do the job already
// there on the first turn? A miss costs a search or an activation, not the task.
const SELECTION_SET = [
  ['Is my server still reachable?', 'Ist mein Server noch erreichbar?', ['http_request', 'execute_command']],
  ['What was on my last invoice?', 'Was stand in meiner letzten Rechnung?', ['session_search', 'memory_recall', 'search_files', 'read_messages']],
  ['What is the weather in Berlin tomorrow?', 'Wie wird das Wetter morgen in Berlin?', ['web_search', 'http_request']],
  ['Remember that I am allergic to peanuts.', 'Merk dir, dass ich gegen Erdnüsse allergisch bin.', ['memory_save', 'memory_write', 'memory_update_core']],
  ['What do you know about my dentist?', 'Was weißt du über meinen Zahnarzt?', ['memory_recall', 'memory_read', 'session_search']],
  ['What did we talk about last week?', 'Worüber haben wir letzte Woche gesprochen?', ['session_search', 'memory_recall']],
  ['Forget my old address.', 'Vergiss meine alte Adresse.', ['memory_forget', 'memory_update_core', 'memory_write']],
  ['Remind me tomorrow at nine to call Anna.', 'Erinnere mich morgen um neun daran, Anna anzurufen.', ['create_task']],
  ['Which reminders do I have set?', 'Welche Erinnerungen habe ich eingerichtet?', ['list_tasks']],
  ['Cancel my morning briefing.', 'Streich mein Morgenbriefing.', ['delete_task', 'update_task']],
  ['Tell Anna on WhatsApp that I am running late.', 'Schreib Anna auf WhatsApp, dass ich später komme.', ['send_message']],
  ['What did Max write to me yesterday?', 'Was hat Max mir gestern geschrieben?', ['read_messages', 'session_search']],
  ['Which chats have unread messages?', 'In welchen Chats gibt es ungelesene Nachrichten?', ['list_chats', 'read_messages']],
  ['Call me when the backup is done.', 'Ruf mich an, wenn das Backup fertig ist.', ['call_user', 'create_task']],
  ['Open the Hacker News front page and tell me the top story.', 'Öffne die Startseite von Hacker News und sag mir die Top-Story.', ['browser_navigate', 'http_request', 'web_search']],
  ['Log in to my electricity provider and download the bill.', 'Log dich bei meinem Stromanbieter ein und lade die Rechnung runter.', ['browser_navigate', 'browser_act']],
  ['Take a screenshot of the website example.com.', 'Mach einen Screenshot von der Webseite example.com.', ['browser_navigate', 'browser_screenshot']],
  ['Find the file that handles login.', 'Finde die Datei, die den Login macht.', ['search_files', 'code_navigate', 'execute_command']],
  ['Run the tests.', 'Führ die Tests aus.', ['execute_command']],
  ['Fix the typo in the README.', 'Korrigier den Tippfehler in der README.', ['edit_file', 'replace_file_range', 'write_file', 'execute_command']],
  ['Undo what you just changed in the code.', 'Mach deine Änderungen am Code rückgängig.', ['workspace_rollback', 'execute_command']],
  ['Open Spotify on my phone.', 'Öffne Spotify auf meinem Handy.', ['android_open_app']],
  ['What is on my phone screen right now?', 'Was ist gerade auf meinem Handybildschirm?', ['android_observe', 'android_screenshot', 'android_dump_ui']],
  ['Open Safari on my Mac.', 'Öffne Safari auf meinem Mac.', ['desktop_launch_app', 'execute_command']],
  ['What window is open on my desktop?', 'Welches Fenster ist auf meinem Desktop offen?', ['desktop_observe', 'desktop_get_tree']],
  ['Draw me a picture of a red fox.', 'Mal mir ein Bild von einem roten Fuchs.', ['generate_image']],
  ['Make a chart of these numbers: 3, 5, 9.', 'Mach ein Diagramm aus diesen Zahlen: 3, 5, 9.', ['generate_graph', 'generate_table']],
  ['What does the text in this photo say?', 'Was steht auf diesem Foto?', ['ocr_extract', 'analyze_image']],
  ['Transcribe the voice note I sent.', 'Schreib die Sprachnachricht ab, die ich geschickt habe.', ['transcribe_audio']],
  ['How many steps did I walk this week?', 'Wie viele Schritte bin ich diese Woche gelaufen?', ['read_health_data']],
  ['What is trending about me on X?', 'Was sagen die Leute auf X gerade über mich?', ['social_reach_search', 'social_reach_read', 'web_search']],
  ['Summarize this YouTube video: https://youtu.be/abc', 'Fass dieses YouTube-Video zusammen: https://youtu.be/abc', ['social_video_extract', 'http_request', 'web_search']],
  ['Connect the Linear MCP server.', 'Verbinde den Linear-MCP-Server.', ['mcp_add_server']],
  ['Save this workflow as a skill.', 'Speicher diesen Ablauf als Skill.', ['create_skill']],
  ['Have a specialist agent review this contract.', 'Lass einen Fach-Agenten diesen Vertrag prüfen.', ['spawn_subagent', 'delegate_to_agent']],
];

function selectionCases() {
  return SELECTION_SET.flatMap(([english, german, tools]) => [
    { request: english, language: 'en', tools },
    { request: german, language: 'de', tools },
  ]);
}

module.exports = {
  selectionCases,
};
