# SIP credential handoff

Date: 2026-10-28

A real PBX REGISTER demonstrated account-password authentication fails while the independently generated SIP credential succeeds. Preserve separate credentials and the existing architecture. Add `sipPassword` to the authenticated HTTPS login response only, with Cache-Control: no-store and a redacted DTO string representation. Do not add it to /me, Push, logs or diagnostic artifacts. Store it using the existing native secure store. Keep the account password hashed on the server and stored securely by the app for re-authentication; never replace the SIP credential with that password. Restart re-authenticates the same installation to refresh session/device generation and the current SIP credential. The existing API fields and all SMI/native identifiers remain unchanged.

This is a correction within F01/F02, not a new feature. Release/device acceptance remains separate. Regression and real PBX evidence is recorded in qa/reports/2026-10-28-call/.
