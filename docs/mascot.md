# The mascot

**NeoAgent's face: a dark tile with a 9×9 dot-matrix screen that shows what the agent is doing right now.**

![The NeoAgent mascot in all eight states](./images/mascot.gif)

## 📍 Where it appears

- **Desktop sidebar.** Live, in place of the logo.
- **Phone top bar.** Live.
- **Chat.** The assistant's avatar; only the newest reply's face is live.
- **Typing bubble.** Thinking while a reply is on its way.
- **Voice call screen.** Live during the call, Done on the recap.
- **Onboarding.** Each step sets its own mood.
- **Android home-screen widgets.** The status and call widgets.
- **Landing page.** In the nav, acting out the hero's run log, and in the footer.
- **Wearable.** The home screen and the status screens.

## 🎭 What each face means

| State | Face | Shown in the app when |
| --- | --- | --- |
| Asleep | Closed eyes and a "z" | The connection to the server is down |
| Waiting | Tall eyes, blinking caret, gold rim | A tool needs your approval |
| Listening | Eyes plus a level-meter mouth | A voice call is listening or the reply is playing |
| Working | Underscore eyes, a light running round the edge | A tool runs, a voice call hands off a task, or a scheduled, task or messaging run is in progress |
| Thinking | Eyes up, three dots counting | Your message is being answered and no tool runs yet |
| Blocked | Red crosses and a frown | Your chat run failed; plays once |
| Done | Happy eyes and a smile | Your chat run finished; plays once |
| Idle | Two cursor eyes that blink or glance now and then | Nothing else applies |

When several apply, the higher row wins.

### ⌚ On the wearable

| State | Shown when |
| --- | --- |
| Thinking | The call is connecting or reconnecting |
| Listening | You hold to talk, or the reply is playing |
| Working | A handed-off task is running |
| Done, Blocked | A handed-off task finished or failed, or the call hit an error |
| Waiting | Setup screens: hotspot, QR pairing, forget device |
| Asleep | The board lost its server connection |

## ⚙️ Behaviour

- **Instant.** Sending a message shows Thinking straight away.
- **Light at rest.** An idle mascot redraws only for its occasional blink or glance.
- **Reduced motion.** Holds a still key frame when the system asks for reduced motion.
- **Landing page.** Pauses while off screen or in a background tab.
- **One face everywhere.** The app, landing page and wearable firmware use the same frames.
