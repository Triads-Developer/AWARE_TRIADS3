# 📱 AWARE Mobile Sensing App – Emotion and Behavior Study

The **AWARE Mobile Sensing App – Emotion and Behavior Study** uses a customized version of the open-source [AWARE Framework](https://awareframework.com/) to passively collect mobile sensor data and deliver automated surveys to participants. The study focuses on understanding how **emotion** and **emotion regulation** relate to everyday behaviors, location patterns, and digital activity.

This customized version includes advanced features such as **context-aware notification delivery**, **geofence-based triggers**, **notification expiration**, and **centralized logging**, allowing for more precise survey timing and improved data quality.

---

## 🧠 Research Background

Our research examines the interplay between emotion, regulation strategies, and environmental context. In prior studies with over 200 undergraduate participants, we used mobile sensing to collect passive data on:
- GPS and mobility patterns
- Physical activity and motion
- Phone and app usage

In this new phase, participants will receive **automated survey prompts**:
- Randomly, four times per day
- **AND** when they remain in a defined neighborhood for 5 or more minutes

This enables us to observe how emotional experiences unfold within real-world contexts.

---

## 🔍 Key Features

- **🔔 Scheduled Notifications**  
  Surveys are sent randomly during four daily time windows (morning, midday, afternoon, evening) across a 7-day period.

- **📍 Location-Triggered Prompts**  
  If participants remain within a geofenced neighborhood for ≥5 minutes, a location-based survey notification is triggered.

- **🕓 Notification Expiration Logic**  
  Unopened notifications expire after 90 seconds and are automatically logged and removed to reduce clutter and improve accuracy.

- **🧾 Centralized Event Logging**  
  All notification events—including sent, delivered, tapped, ignored, and expired—are logged with timestamp, location, and type.

- **🌐 GeoJSON Integration**  
  Uses a `Neighborhoods-4.geojson` file to define custom polygon boundaries for neighborhood geofencing.

- **📡 Secure Syncing**  
  Logged data is transmitted to a secure AWARE server for storage and post-study analysis.

---

## 🛠 Getting Started

### For Participants

1. **Download the App**
   - **Android**: Available on the Google Play Store
   - **iOS**: Distributed via TestFlight or direct install

2. **Enable Permissions**
   - Allow **Location Access** (Always)
   - Allow **Push Notifications**
   - Consent to participation in the study

3. **Keep the App Running**
   - The app collects sensor data and sends/receives notifications automatically in the background.

---

## 🔐 Data Privacy & Ethics

- All data is **anonymized** and tied to a randomly generated device ID.
- Participants can withdraw at any time without penalty.
- Survey and sensor data are stored on a secure, university-managed AWARE server.
- All research procedures comply with approved **IRB protocols**.

---

## 📊 Data Analysis Plan

After collection, the dataset will be used to analyze links between emotional states and behavioral context using statistical models and machine learning. We will focus on:
- Emotion regulation strategies
- Physical and social activity levels
- Contextual behavioral changes across time and space

---

## 💻 For Developers

This version extends the AWARE iOS client to support:

| File / Component             | Description |
|-----------------------------|-------------|
| `AppDelegate.swift`         | Handles app launch, schedules randomized notifications |
| `LocationHandler.swift`     | Tracks geofence entry, enforces 5-minute dwell condition |
| `NotificationLogger.swift`  | Centralized logging of all notification events |
| `Neighborhoods-4.geojson`   | Defines geographic polygons for location-based triggering |
| `AWAREEventLogger.swift`    | Logs expiration and interaction events to local DB |

---

## 🤝 Contributing & Contact

We welcome collaboration from researchers, developers, and institutions interested in mobile sensing and emotion research.

**Contact us at:** [A&S Triads Developers <triads.developers@wustl.edu>]  
Let us know if you’d like to:
- Contribute to the app or study design
- Reuse the platform for your own studies
- Collaborate on data analysis or interpretation

![AWARE Framework](https://blogs.unimelb.edu.au/aware-light/files/2020/10/image-10.png)

---



