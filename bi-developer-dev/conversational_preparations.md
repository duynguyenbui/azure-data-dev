# Conversational Preparations & Behavioral Guide

## Interviewer Pronunciation Guide

- **Anurag Jain**: Pronounced _Ah-noo-rahg Jane_ (Cách đọc tiếng Việt: A-nu-rắc Giên)
- **Amal Kocherla**: Pronounced _Ah-mahl Koh-chair-lah_ (Cách đọc tiếng Việt: A-man Cô-che-la)

---

## 1. Career History (The "Tell Me About Yourself" Pitch)

> "I’m currently an SQL - Data Developer at Ready Workforce, where my day-to-day focus is working extensively with SQL to extract and transform data, and then building actionable reports for our business stakeholders. Over the past few years, I’ve built a strong technical foundation in SQL Server, data architecture, and query optimization. I really enjoy bridging the gap between raw backend data solutions and front-end business insights, which is why I’m so excited to speak with you both at Pinnacle Group. I’m looking for a dedicated BI Developer role where I can leverage my strong SQL foundation to build scalable data systems and drive data-driven decision-making."

---

## 2. Handling Feedback, Pressure, and Mistakes

> "In a recent project, an unexpected change in the source data caused one of our critical reporting stored procedures to fail, resulting in incomplete data for the morning reports. Under pressure, my first action was to immediately communicate the delay to stakeholders so they were aware and could manage expectations. Then, I dug into the data, identified the logic gap in the stored procedure handling the new data edge cases, and pushed a hotfix. To prevent this from happening again, I added robust error-handling and data validation steps directly within the stored procedure. It was a stressful morning, but the feedback from the business was positive because I was transparent about the issue and put a permanent safeguard in place."

## 3. Current Role – Projects & Tools

> "At Ready Workforce, my primary focus is working with data and SQL to deliver reports for the business. I own the end-to-end process of gathering reporting requirements, architecting the complex T-SQL queries to pull and transform the data, and delivering the final analytics to stakeholders. A recent high-impact project I worked on involved taking a slow, manual data extraction process and replacing it with an optimized SQL stored procedure. By replacing inefficient cursors with set-based logic, I was able to generate the report significantly faster, ensuring our analytics systems were both scalable and reliable. It’s this mix of deep SQL architecture and direct analytics delivery that I spend most of my time on."

## 4. Likes and Dislikes About Your Current Role at Ready Workforce

> "What I really enjoy about my role at Ready Workforce is the technical depth—I love getting into the weeds of data architecture, performance tuning complex SQL queries, and building out robust reporting systems. It’s highly satisfying to make data extraction run faster and more reliably. However, because my role is heavily focused on data prep and backend SQL, I don’t always get to see how the business ultimately interacts with those analytics. I’m looking for a role with more of a BI focus because I want to bridge that gap—combining scalable backend data solutions with front-end analytics to drive direct business value."

## 5. Career Goals (2–3 Year Plan)

> "Over the next 2-3 years, I want to transition from being an SQL Data Developer into a comprehensive BI Architect. I plan to deepen my expertise in enterprise analytics systems and modern cloud data architectures, like Azure. My goal is to be the go-to person who not only ensures the data solutions are perfectly optimized and scalable, but also understands exactly how those systems power strategic analytics and business insights."

## 6. Ideal Work Environment & What You Seek in a New Role

> "I thrive in collaborative environments where knowledge sharing is part of the culture, and where cross-functional teams work closely together. I’m looking for a role that offers a healthy mix of deep technical data challenges and business-facing analytics impact. Pinnacle Group stands out to me because it seems like a place where I can leverage my heavy SQL architecture background to make an immediate impact, while also growing into a more comprehensive BI and data systems role."

## 7. Icebreaker / Lighthearted Joke (Optional)

> **Safe alternative:** "To be honest, in my early days, I think StackOverflow and random 10-hour YouTube tutorials deserve half the credit for my SQL skills!"
>
> _(Note: Keep it light and relatable, focusing on the universal developer experience rather than specific groups)._

## 8. Explaining Your Technical Code (SQL Walkthroughs)

When the interviewers ask you to walk them through the code you wrote for the technical test, use these templates to sound confident and senior.

### 8a. Explaining `ROW_NUMBER()` (Deduplication / Latest Record)

> "To solve this, I used a Common Table Expression (CTE) paired with the `ROW_NUMBER()` window function. I partitioned the data by the unique identifier and ordered it descending by the date. This assigns a '1' to the most recent record. Then, I simply filter for `row_num = 1` (or delete where `row_num > 1`). I prefer this over a correlated subquery because `ROW_NUMBER()` only requires a single pass over the data, making it highly scalable and much faster for large tables."

### 8b. Explaining Dynamic Grouping (`GROUP BY` with `CASE WHEN`)

> "For this reporting requirement, I needed to merge specific categories together on the fly. Instead of building messy staging tables or writing multiple `UNION` statements, I embedded a `CASE WHEN` statement directly into the `GROUP BY` clause. By forcing the edge cases to share the exact same grouping key, the SQL engine automatically collapses and aggregates them into a single row. It keeps the code clean and maintains high performance."

### 8c. Explaining Query Optimization (Replacing Cursors / Loops)

> "When I look at optimizing a slow reporting process, my first goal is always to eliminate row-by-row operations. In a recent project, I found a stored procedure relying heavily on cursors, which was causing major bottlenecks. I rewrote the logic to use pure set-based operations—specifically using indexed temp tables and standard joins. By letting the SQL Server engine handle the data in bulk rather than looping, we reduced the report generation time drastically."
