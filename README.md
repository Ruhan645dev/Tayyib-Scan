# 🟢 Tayyib Scan

**Tayyib Scan** is an intelligent mobile application designed to help Muslims identify Halal, Haram, and Mushbooh (doubtful) ingredients instantly. It utilizes On-Device Machine Learning (OCR) and Barcode scanning to analyze food products in real-time.



## Features

- **Text Scanning (OCR):** Uses Google ML Kit to read ingredients lists from packaging.
- **Barcode Scanning:** Integrates with OpenFoodFacts API to fetch product data globally.
- **Traffic Light Logic:**
  - **Red:** Haram (Pork, Alcohol, E120).
  - **Yellow:** Mushbooh (Doubtful additives).
  -  **Green:** Safe/Halal.
- **History:** Saves previous scans with images locally.
- **Offline First:** Text analysis logic runs entirely on-device for speed and privacy.

## 🛠️ Tech Stack

- **Framework:** Flutter (Dart)
- **State Management:** StatefulWidget & Async/Await
- **AI/ML:** Google ML Kit (Text Recognition & Barcode Scanning)
- **Ads:** Google AdMob (Native & Interstitial)
- **Storage:** Shared Preferences & Path Provider
- **Networking:** HTTP (OpenFoodFacts API)

