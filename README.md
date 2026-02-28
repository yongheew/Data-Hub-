# Team PenangOneBetter – DataHub 📊🤖
> **Build on History, Designed for Better Desicisons.**

Welcome to DataHub! 🤗

DataHub is an AI-powered operational memory system for workers, managers, users that turns history and reports from a particular organization into structured, actionable intelligence using Vertex AI.

## Table of Contents
- [Introduction](#introduction)
- [Project Overview](#project-overview)
- [Key Features](#key-features)
- [Technologies Used](#technologies-used)
- [Implementation Details & Innovation ](#implementation-details-&-innovation)
- [Workflow](#workflow) 

## Introduction     
DataHub is an AI-powered operational intelligence platform built using Firebase, Google Cloud, Flutter, Gemini, and Vertex AI. It provides organizations with a centralized system to capture, interpret, and utilize frontline incident reports, enabling faster responses and more informed decision-making. Moving beyond fragmented logs and disconnected reporting methods, DataHub transforms unstructured inputs into actionable insights, helping teams detect recurring issues early, improve workplace safety, and enhance operational efficiency.

**Team Members**
1. Wong Yonghee - AI / Logic Implementation (Team Leader)
2. Lim Ying Yu - Frontend Designer 
3. Sheryl Khoo Zoe Ee - Backend Developer

## Project Overview:
**Problem Statement**     
Frontline workers such as security guards, maintenance staffs, cleaners, and facility operators are responsible for recording incidents, managing daily operations, and responding to issues across shifts. These are often reported using handwritten logs, WhatsApp messages, spreadsheets, and disconnected systems.  

Though these reports are recorded, they are often unstructured and inconsistent, which leads to lack of coherent operation memory from the organizations. Recurring issues are treated as isolated events, patterns are missed, and preventable failures continue. Supervisors must manually review scattered data, leading to <ins>slow responses, inefficient planning</ins>, and increased safety risks. 
> A traditional database can store data, but it cannot understand meaning, detect semantic similarities or connect records over time. This is where **AI** step into the game.

**SDG Alignment**    
This project is highly related to 2 SDGs, which are SDG 8 and SDG 9.
1. ``SDG 8 💼 - Decent Work and Economic Growth``: Enhances workplace efficiency and safety.
2. ``SDG 9 🏗️ - Industry, Innovation, and Infrastructure:`` Improves operational infrasturcture and enables better decision-making through technology.

**Solution**     
DataHub transforms unstructured operational inputs into a persistent, intelligence system memory. Instead of acting as a chatbot, it builds <ins>historical understanding across time, locations, and incidents</ins> to help organizations make better decisions based on accumulated data.

It allows workers to log issues easily, while AI structures, links, and analyzes those records to surface patterns and insights.

## Key Features     
- 📝 Simple text and optional voice-based incident logging
- 🧠 AI-powered summurization and structuring of frontline reports
- 🔗 Linking of new records to related historical incidents
- 🚨 Recurrence detection for frequently occuring issues
- 📊 Basic dashboard view of incident trends and history

## Technologies Used
**Google Technologies**
1. ``Gemini API:`` for natural language understanding and summarization
2. ``Vertex AI:`` for inident classification and severity estimation (including risk prediction)
3. ``Firebase Authentication:`` for secure user access
4. ``Cloud Firestore:`` for real-time data storage  

**Other Supporting Tools/ Libraries**
1. ``Flutter:`` for building the cross-platform frontend (web + mobile) UI
2. ``GitHub:`` for version control and collaboration use

## Implementation Details & Innovation & System Architecture
1. **Frontend Layer**
- Flutter-based mobile/web application
- Firebase Authentication for secure login
- Role-based access (Frontline staff vs Supervisors)

2. **Backend Layer**
- Firebase Cloud Functions to orchestrate workflows
- Gemini API for natural language understanding and semantic structuring
- Vertex AI for classification, severity estimation, and recurrence risk modeling

3. **Data Layer**
- Firestore as persistent operational memory (raw + structured records)
- BigQuery for historical aggregation, analytics, and dashboards

We separated:
Data ingestion, AI structuring, Pattern detection, Insight generation

This ensures scalability and interpretability. AI outputs are always grounded in stored data rather than generated independently.

## Workflow
1. **Input (Text or Voice)**
Frontline worker logs an incident in natural language.

Example:
```“Lights at court 2 flickering again.”```

2. **AI Structuring (Gemini)**
Gemini extracts:
- Location: Court 2
- Issue type: Electrical
- Recurrence indicator: Yes
- Severity level
- Timestamp

It also generates a concise structured summary.

3. **Operational Memory (Firestore)**
Both raw input and structured attributes are stored.
This creates persistent site-specific historical memory.

4. **Pattern Detection (Vertex AI)**
Vertex AI:
- Classifies issue category
- Estimates recurrence probability
- Detects semantically similar past incidents
- Flags unusual frequency spikes

5. **Insight Generation**
System surfaces:
- Related past records
- Recurrence alerts
- Preventive recommendations grounded in stored data
- Dashboard trend analytics

The intelligence improves over time as more data accumulates.

**Innovation**
1. Persistent Operational Memory
Unlike chat-based AI tools, DataHub accumulates site-specific intelligence over time. It does not rely solely on prompts — it reasons over historical operational data.

“Reporting creates data; our system creates decision context.”

2. Semantic Recurrence Detection
Instead of keyword matching, the system uses AI-based semantic similarity to link:
- “Court lights not working”
- “Lighting failure at court 2”
- “Flickering lights again”

3. AI as a Structuring Layer (Not Replacement)
AI is used to:
- Transform unstructured input into structured data
- Maintain semantic consistency
- Identify patterns across time

It does not replace human decision-making.
It enhances clarity and efficiency.

## Challenges Faces
1. Ensuring AI Outputs Were Reliable and Grounded

Large language models can generate speculative outputs.

Solution:
We restricted AI to:
- Summarization
- Attribute extraction
- Semantic linking

All recommendations must reference stored historical records.

2. Handling Inconsistent Frontline Language
Frontline staff describe the same issue differently.

3. Balancing Simplicity with Intelligence
Users wanted minimal input effort.
Solution:
- Short text or voice logging
- AI auto-structuring
- Concise, non-chatty outputs

Solution:
Semantic similarity detection via Gemini embeddings rather than keyword matching.

## Installation & Setup (Prototype)
**Prerequisites**
Google Cloud Project
Firebase Project
Enabled APIs:
- Firebase Authentication
- Firestore
- Cloud Functions
- Vertex AI
- Gemini API
- BigQuery

**Setup Steps**
1. Clone Repository  
```git clone <repository-link> ```           
```cd datahub```
2. Install Dependencies
```flutter pub get ```
3. Run Application on chrome
``` flutter run -d chrome ```

And you're all set!
