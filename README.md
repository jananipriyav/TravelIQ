# 🚀 TravelIQ — AI-Powered Smart Urban Travel Planner

> Intelligent multi-destination trip planning with deadline-aware route optimization, multi-transport recommendations, CO₂ tracking, and real-time navigation.

TravelIQ is a Flutter-based smart urban travel planner designed to solve a common problem with conventional navigation apps: **they help you navigate between locations, but they don't intelligently plan an entire multi-stop trip around your schedule.**

TravelIQ allows users to enter multiple destinations, specify dwell times and a final arrival deadline, and automatically generates an optimized itinerary based on the user's preferred objective — **Fastest, Cheapest, or Eco-friendly**.

---

## 🎯 Problem Statement

Urban travelers often need to visit multiple places within a limited amount of time.

For example:

> Home → Shopping Mall → Restaurant → Theatre → Metro Station

Existing navigation applications primarily focus on point-to-point navigation. The user has to manually decide:

- Which destination to visit first
- Which route is better
- Which transport mode to use
- Whether the entire trip fits within the deadline
- How much the trip may cost
- How much CO₂ it produces

TravelIQ addresses these challenges by combining **route optimization, deadline constraints, transport recommendations, mapping services, and personalized trip planning** into a single application.

---

## 💡 Our Solution

TravelIQ automatically:

1. Detects the user's current location.
2. Accepts multiple destinations.
3. Identifies the final destination.
4. Collects dwell time for intermediate stops.
5. Takes the user's arrival deadline.
6. Generates possible visiting sequences.
7. Calculates travel time for each sequence.
8. Removes routes that violate the deadline.
9. Optimizes the remaining routes according to:
   - ⚡ Fastest
   - 💰 Cheapest
   - 🌱 Eco
10. Recommends suitable transport modes.
11. Displays the optimized itinerary on a map.
12. Provides estimated arrival times, fares, and CO₂ emissions.
13. Allows the user to hand off individual legs to Google Maps.
14. Schedules departure reminders.
15. Saves completed trips to travel history.

---

# ✨ Key Features

## 🔐 1. Authentication

- User registration and login
- Email/password authentication
- Supabase Authentication
- Persistent login sessions
- User profile stored separately in the database

---

## 🏠 2. Smart Home Dashboard

The dashboard provides:

- Personalized greeting
- Current user information
- Quick trip planning
- Travel statistics
- Navigation to:
  - Home
  - History
  - Profile

---

## 📍 3. Real-Time Location

The application retrieves the user's GPS location and displays it on an interactive map.

The detected location automatically becomes the **starting point** of the trip.

---

## 🔎 4. Intelligent Destination Search

TravelIQ uses OpenStreetMap's Nominatim service for location search.

Features include:

- Search-as-you-type
- Debounced API requests
- Minimum character validation
- Location suggestions
- Automatic coordinate retrieval

---

# 🧠 5. Multi-Destination Trip Planning

Users can add multiple destinations instead of planning only one route.

For every location, the application asks:

> **"Is this your final destination?"**

If the answer is:

### Yes
The location becomes the final destination.

### No
The location becomes an intermediate stop and the user provides:

- Dwell time
- Expected duration of stay

This allows TravelIQ to understand the user's complete schedule.

---

# ⏰ 6. Deadline-Aware Planning

Users can specify:

> "I need to reach my final destination by 7:00 PM."

The optimizer considers:

- Travel time
- Dwell time
- Destination order
- Arrival deadline

Routes that cannot satisfy the deadline are eliminated.

If no route can satisfy the deadline, TravelIQ provides the **least-late feasible route** instead of simply failing.

---

# ⚡ 7. Multi-Objective Route Optimization

TravelIQ introduces three optimization objectives:

### ⚡ Fastest

Prioritizes minimum total travel time.

### 💰 Cheapest

Prioritizes minimum estimated transportation cost.

### 🌱 Eco

Prioritizes minimum estimated CO₂ emissions.

The deadline remains a hard constraint in all three modes.

---

# 🤖 8. AI / Optimization Engine

The core optimization engine uses a **Traveling Salesman Problem (TSP)-based approach**.

For a trip containing a small number of destinations, the system evaluates different possible visiting sequences.

Example:

```text
A → B → C → D
A → B → D → C
A → C → B → D
A → C → D → B
...
