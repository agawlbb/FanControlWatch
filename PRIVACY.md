# Privacy

Fan Control for Apple Watch sends pairing, configuration, state and command requests directly to the Home Assistant addresses you configure. It has no developer-operated backend, advertising, analytics or tracking SDK. Home Assistant and your configured remote-access provider handle those requests under their own policies.

The watch stores its independent revocable Home Assistant integration credential and approved configuration in the device-only Keychain, accessible while unlocked. It does not store your Home Assistant account password or Spotify credentials. Forget connection removes the local credential; revoke the watch in Home Assistant to remove server access.

Exercise music is copied privately from your configured Home Assistant into the watch's app storage using the paired encrypted protocol. Audio stays on your HA server and watch; it is not sent to the developer or included in public source/build artifacts. The watch remembers the preferred headset's system audio-route identifier locally. Forget connection removes locally stored exercise music and that identifier. Exercise uses local playback and does not open Spotify or send Spotify playback requests. Vehicle commands and observations go through Home Assistant; they do not independently prove physical vehicle state.

Apple may provide TestFlight crash, diagnostic and beta feedback data under Apple's TestFlight policies. Do not include credentials or private entity details in public GitHub issues. Report security concerns privately through the repository's GitHub security reporting feature when available.
