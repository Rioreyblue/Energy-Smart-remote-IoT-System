# Foreground Alert Audio

1. remove-just-audio-loop — Delete the Flutter audio loop logic added previously.
2. native-service-setup — Create an Android foreground service (Kotlin) that plays the alert tone and expose platform channels.
3. flutter-bridge — Add MethodChannel helpers to start/stop the service when threshold alerts trigger or stop.
4. scheduling-integration — Ensure Workmanager/threshold monitor starts the native service even if app is closed.
5. qa-documentation — Test on-device (foreground/background/terminated) and document the workflow.

### To-dos

- [ ] Remove current Flutter audio looping code and dependencies.
- [ ] Add native service + channel wiring.
- [ ] Hook service calls into threshold alert flow.
- [ ] Validate behavior across app states and note platform requirements.
