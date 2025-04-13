---
title: "Learning OpenTelemetry book review"
date: 2025-04-13T11:17:39+02:00
tags: ["OpenTelemetry", "book review"]
cover:
  image: "learning-opentelemetry-book-review.jpg"
  alt: "Learning Opentelemetry Book Review"
---

I recently finished reading [Learning OpenTelemetry](https://learning.oreilly.com/library/view/learning-opentelemetry/9781098147174/) by Ted Young and Austin Parker. I recommend this book to everyone interested in a deeper understanding of observability.

The authors focus first on providing historical context for telemetry and how the signals evolved. I particularly liked two concepts: soft and hard context and signal layering. They also explain how the current monitoring landscape looks and why OpenTelemetry was created.

The authors explain the difference between OpenTelemetry API and SDK and instrumenting library vs. application. They give an overview of the OpenTelemetry Demo and provide some checklists for setup. The book misses the code examples; it focuses on general concepts and not language-specific implementation.

The last part of the book describes the OpenTelemetry Collector. The authors give a wide overview of the capabilities of the Collector by describing the most popular processors. They describe Collector deployment patterns like agent, gateway and how to set up collectors for tail-sampling. They mention a lot of advanced topics like OpAMP or OTel arrow protocol although briefly. The monitoring of the infrastructure like hosts and Kubernetes is also described.

In the end, the authors give a lot of good patterns for rolling out OpenTelemetry in larger organizations. They write how to approach: deep or wide, centralized or decentralized, and how to engage teams.

To sum up, I can highly recommend *Learning OpenTelemetry*. I think it is a very good book for SREs, Observability, Platform teams, or developers wanting to learn more about observability. It is a good complement to the official documentation.