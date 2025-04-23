## 📱 AWARE Mobile Sensing App – Emotion and Behavior Study

The AWARE Mobile Sensing App - Emotion and Behavior Study plans to use the mobile sensing app AWARE (https://awareframework.com/) to collect data from participants next semester while using a different app to send them surveys to their phones every two hours. AWARE is an open source software that enables the project to collect data such as GPS, activity, phone use, etc. The project wants to then look at how emotion and emotion regulation are related to these passively sensed contextual features.

This project builds on the open-source [AWARE Framework](https://awareframework.com/) and introduces **enhanced notification logic**, **location-based triggers**, and **centralized logging**, enabling researchers to better time and contextualize survey delivery.

---
## 🧠 Research Background

Our research team studies the relationship between **emotion**, **emotion regulation**, and **contextual behavior**. In a previous study with 200 undergraduate participants, we used the AWARE app to collect mobile sensor data (e.g., location, activity, phone usage).

This updated version introduces **automated survey prompts** via notifications—sent every two hours (randomized) or when users spend significant time in a specific location—allowing for fine-grained analysis of emotional regulation in daily life.

---

## 🔍 Key Features

- **🔔 Scheduled Notifications**: Participants receive surveys at randomized intervals during waking hours (4 time windows/day × 7 days).
- **📍 Location-Triggered Surveys**: Notifications are sent when users spend ≥5 minutes in a designated neighborhood.
- **🧾 Logging System**: All notification interactions (scheduled, delivered, opened, ignored) are logged with time, location, and category.
- **🌐 GeoJSON Integration**: Supports custom geofencing boundaries defined by neighborhood polygons.
- **📡 Secure Sync**: Logs are sent to an AWARE server instance for secure storage and analysis.

---

## 🛠 Getting Started

### For Participants

1. **Download the App**  
   - Android: [Google Play Store](https://play.google.com)  
   - iOS: Custom app provided for iPhone users.

2. **Consent to Notifications & Location Access**  
   Participants must enable both permissions and agree to receive:
   - Surveys every two hours (via push notifications)
   - Occasional location-based surveys

3. **Keep the App Running**  
   The app passively collects data in the background and automatically logs contextual behaviors.

---

## 🔐 Data Privacy & Ethics

- All collected data is **anonymized** using a secure device ID.
- Participants may withdraw at any time.
- Survey responses and sensor data are stored securely and handled in compliance with institutional review board (IRB) protocols.

---

## 📊 Data Analysis Plan

Sensor streams will be combined with survey data and analyzed using **machine learning algorithms** to uncover relationships among:
- Physical activity
- Social interaction

---

## 💻 For Developers

This app includes enhanced logging and survey scheduling features:
AppDelegate.swift            → Schedules random survey notifications and handles iOS launch/config
Location_Fused2.swift        → Tracks GPS, identifies neighborhood stay duration, triggers location-based alerts
NotificationLogger.swift     → Deduplicates and formats event logs for delivery to AWARE server
Neighborhoods-4.geojson      → GeoJSON file for neighborhood polygon boundaries


### Contributing

If you are interested in contributing to the study or have any questions, please contact the project at [email address]. They welcome collaborations with researchers and institutions interested in understanding the relationship between behavior patterns and emotion regulation
<img src="https://blogs.unimelb.edu.au/aware-light/files/2020/10/image-10.png" alt="Alt text" title="Optional title"> 

