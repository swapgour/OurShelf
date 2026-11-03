/// The OAuth "Web client ID" Firebase generates once Google Sign-In is
/// enabled and at least one SHA certificate fingerprint is registered on the
/// Android app (Project settings > Your apps). It shows up as an
/// `oauth_client` entry of type 3 in a freshly downloaded google-services.json.
///
/// Required by google_sign_in on Android so the ID token it returns has the
/// right audience for Firebase Auth to accept.
const String googleServerClientId =
    '982511618078-m5ngkm3q9fhu76p3g6tgvpcq79poesv9.apps.googleusercontent.com';
