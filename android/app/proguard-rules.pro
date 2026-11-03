# google_mlkit_text_recognition ships optional per-script recognizer classes
# (Chinese/Devanagari/Japanese/Korean) that are only present if you add the
# matching script dependency. This app only uses TextRecognitionScript.latin,
# so those classes are never loaded at runtime — R8 just needs to be told
# not to fail the build over references to classes we deliberately don't ship.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
