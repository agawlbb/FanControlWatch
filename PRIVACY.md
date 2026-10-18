# Privacy

Fan Control for Apple Watch sends pairing, configuration, state and command requests directly to the Home Assistant addresses you configure. It has no developer-operated backend, advertising, analytics or tracking SDK. Home Assistant and your configured remote-access provider handle those requests under their own policies.

The watch stores its independent revocable Home Assistant integration credential and approved configuration in the device-only Keychain, accessible while unlocked. It does not store your Home Assistant account password or Spotify credentials. Forget connection removes the local credential; revoke the watch in Home Assistant to remove server access.

Exercise Start can ask the installed Spotify app to open and send the separately configured HA music request. The app cannot establish actual playback from that acknowledgment. Vehicle commands and observations go through Home Assistant; they do not independently prove physical vehicle state.

Apple may provide TestFlight crash, diagnostic and beta feedback data under Apple's TestFlight policies. Do not include credentials or private entity details in public GitHub issues. Report security concerns privately through the repository's GitHub security reporting feature when available.
