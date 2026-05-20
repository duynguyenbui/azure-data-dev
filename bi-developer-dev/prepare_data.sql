IF OBJECT_ID('JobPostings', 'U') IS NOT NULL DROP TABLE JobPostings;
IF OBJECT_ID('Employees', 'U') IS NOT NULL DROP TABLE Employees;
IF OBJECT_ID('Sales', 'U') IS NOT NULL DROP TABLE Sales;
IF OBJECT_ID('UserLogins', 'U') IS NOT NULL DROP TABLE UserLogins;
IF OBJECT_ID('Subscriptions', 'U') IS NOT NULL DROP TABLE Subscriptions;
IF OBJECT_ID('EmployeeSkills', 'U') IS NOT NULL DROP TABLE EmployeeSkills;
IF OBJECT_ID('ServerStatusLogs', 'U') IS NOT NULL DROP TABLE ServerStatusLogs;
IF OBJECT_ID('EmployeeSalaries', 'U') IS NOT NULL DROP TABLE EmployeeSalaries;
IF OBJECT_ID('SalesQuarterly', 'U') IS NOT NULL DROP TABLE SalesQuarterly;
IF OBJECT_ID('DimCustomer', 'U') IS NOT NULL DROP TABLE DimCustomer;
IF OBJECT_ID('CustomerStaging', 'U') IS NOT NULL DROP TABLE CustomerStaging;
IF OBJECT_ID('MonthlyRevenue', 'U') IS NOT NULL DROP TABLE MonthlyRevenue;
IF OBJECT_ID('SourceOrders', 'U') IS NOT NULL DROP TABLE SourceOrders;
IF OBJECT_ID('TargetOrders', 'U') IS NOT NULL DROP TABLE TargetOrders;
IF OBJECT_ID('FactSales', 'U') IS NOT NULL DROP TABLE FactSales;
IF OBJECT_ID('DimDate', 'U') IS NOT NULL DROP TABLE DimDate;
IF OBJECT_ID('DimProduct', 'U') IS NOT NULL DROP TABLE DimProduct;
IF OBJECT_ID('DimStore', 'U') IS NOT NULL DROP TABLE DimStore;
IF OBJECT_ID('Orders', 'U') IS NOT NULL DROP TABLE Orders;
IF OBJECT_ID('dbo.fn_GetAgeInYears',           'FN') IS NOT NULL DROP FUNCTION dbo.fn_GetAgeInYears;
IF OBJECT_ID('dbo.fn_GetActiveEmployeesByDept', 'IF') IS NOT NULL DROP FUNCTION dbo.fn_GetActiveEmployeesByDept;

GO

-- ==========================================
-- Problem 1: Job Postings
-- ==========================================
CREATE TABLE JobPostings (
    job_id INT PRIMARY KEY,
    company_id INT,
    title VARCHAR(100)
);

INSERT INTO JobPostings (job_id, company_id, title) VALUES
(248, 827, 'Business Analyst'),
(149, 845, 'Business Analyst'),
(945, 345, 'Data Analyst'),
(164, 345, 'Data Analyst'),
(172, 244, 'Data Engineer');

GO

-- ==========================================
-- Problem 2: Employees
-- (also reused in Problems 6, 15, 16)
-- ==========================================
CREATE TABLE Employees (
    employee_id INT PRIMARY KEY,
    name VARCHAR(100),
    salary INT,
    department_id INT,
    manager_id INT NULL
);

INSERT INTO Employees (employee_id, name, salary, department_id, manager_id) VALUES
(1, 'Emma Thompson', 3800, 1, 6),
(2, 'Daniel Rodriguez', 2230, 1, 7),
(3, 'Olivia Smith', 7000, 1, 8),
(4, 'Noah Johnson', 6800, 2, 9),
(5, 'Sophia Martinez', 1750, 1, 11),
(6, 'Liam Brown', 13000, 3, NULL),
(7, 'Ava Garcia', 12500, 3, NULL),
(8, 'William Davis', 6800, 2, NULL),
(9, 'Isabella Wilson', 11000, 3, NULL),
(10, 'James Anderson', 4000, 1, 11),
(11, 'Mia Taylor', 10800, 3, NULL),
(12, 'Benjamin Hernandez', 9500, 3, 8),
(13, 'Charlotte Miller', 7000, 2, 6),
(14, 'Logan Moore', 8000, 2, 6);

GO

-- ==========================================
-- Problem 3: Sales
-- ==========================================
CREATE TABLE Sales (
    sale_id INT PRIMARY KEY,
    salesperson_id INT,
    sale_date DATE,
    amount INT
);

INSERT INTO Sales (sale_id, salesperson_id, sale_date, amount) VALUES
(1, 101, '2023-10-01', 500),
(2, 101, '2023-10-02', 300),
(3, 101, '2023-10-03', 700),
(4, 102, '2023-10-01', 450),
(5, 102, '2023-10-03', 900),
(6, 101, '2023-10-04', 200),
(7, 102, '2023-10-04', 600);

GO

-- ==========================================
-- Problem 4: UserLogins
-- ==========================================
CREATE TABLE UserLogins (
    login_id INT PRIMARY KEY,
    user_id INT,
    login_date DATE
);

INSERT INTO UserLogins (login_id, user_id, login_date) VALUES
(1, 1, '2023-01-01'),
(2, 1, '2023-01-02'),
(3, 1, '2023-01-03'),
(4, 1, '2023-01-06'),
(5, 1, '2023-01-07'),
(6, 2, '2023-01-01'),
(7, 2, '2023-01-05');

GO

-- ==========================================
-- Problem 5: Subscriptions
-- ==========================================
CREATE TABLE Subscriptions (
    sub_id INT PRIMARY KEY,
    customer_id INT,
    start_date DATE,
    end_date DATE NULL,
    status VARCHAR(50)
);

INSERT INTO Subscriptions (sub_id, customer_id, start_date, end_date, status) VALUES
(1, 1001, '2023-01-01', '2023-03-31', 'Cancelled'),
(2, 1002, '2023-02-15', NULL, 'Active'),
(3, 1001, '2023-05-01', NULL, 'Active'),
(4, 1003, '2023-01-10', '2023-02-10', 'Cancelled');

GO

-- ==========================================
-- Problem 7: EmployeeSkills
-- ==========================================
CREATE TABLE EmployeeSkills (
    employee_id INT,
    skill_name VARCHAR(50),
    proficiency INT
);

INSERT INTO EmployeeSkills (employee_id, skill_name, proficiency) VALUES
(1, 'SQL', 5),
(1, 'Python', 4),
(2, 'SQL', 3),
(2, 'Python', 5),
(2, 'PowerBI', 4),
(3, 'PowerBI', 5);

GO

-- ==========================================
-- Problem 8: BillOfMaterials
-- ==========================================
IF OBJECT_ID('BillOfMaterials', 'U') IS NOT NULL DROP TABLE BillOfMaterials;

CREATE TABLE BillOfMaterials (
    ComponentID INT PRIMARY KEY,
    ComponentName VARCHAR(100),
    ParentComponentID INT,
    QuantityRequired INT
);

INSERT INTO BillOfMaterials (ComponentID, ComponentName, ParentComponentID, QuantityRequired)
VALUES 
    (1, 'Bicycle', NULL, 1),
    (2, 'Wheel Assembly', 1, 2),
    (3, 'Frame', 1, 1),
    (4, 'Tire', 2, 1),
    (5, 'Rim', 2, 1),
    (6, 'Spoke', 2, 36),
    (7, 'Handlebar', 1, 1),
    (8, 'Grip', 7, 2),
    (9, 'Brake Cable', 7, 2);

GO

-- ==========================================
-- Problem 9: ServerStatusLogs
-- ==========================================
CREATE TABLE ServerStatusLogs (
    log_id INT PRIMARY KEY,
    server_id VARCHAR(50),
    status VARCHAR(50),
    log_time DATETIME
);

INSERT INTO ServerStatusLogs (log_id, server_id, status, log_time) VALUES
(1, 'Server_A', 'Online',  '2023-10-01 10:00:00'),
(2, 'Server_A', 'Online',  '2023-10-01 10:15:00'),
(3, 'Server_A', 'Offline', '2023-10-01 10:30:00'),
(4, 'Server_A', 'Offline', '2023-10-01 10:45:00'),
(5, 'Server_A', 'Offline', '2023-10-01 11:00:00'),
(6, 'Server_A', 'Online',  '2023-10-01 11:15:00'),
(7, 'Server_B', 'Online',  '2023-10-01 10:00:00'),
(8, 'Server_B', 'Offline', '2023-10-01 10:10:00');

GO

-- ==========================================
-- Problem 10 & 11: EmployeeSalaries
-- ==========================================
CREATE TABLE EmployeeSalaries (
    emp_id INT PRIMARY KEY,
    name VARCHAR(100),
    department VARCHAR(50),
    salary INT
);

INSERT INTO EmployeeSalaries (emp_id, name, department, salary) VALUES
(1, 'Alice Turner',  'Engineering', 90000),
(2, 'Bob Chen',      'Engineering', 110000),
(3, 'Carol White',   'Engineering', 95000),
(4, 'David Kim',     'Engineering', 80000),
(5, 'Eva Green',     'Engineering', 105000),
(6, 'Frank Lopez',   'Sales', 55000),
(7, 'Grace Hall',    'Sales', 60000),
(8, 'Henry Scott',   'Sales', 55000),
(9, 'Isla Brown',    'Sales', 72000);

GO

-- ==========================================
-- Problem 12: SalesQuarterly
-- ==========================================
CREATE TABLE SalesQuarterly (
    sale_year INT,
    product_name VARCHAR(100),
    total_revenue INT
);

INSERT INTO SalesQuarterly (sale_year, product_name, total_revenue) VALUES
(2022, 'Laptop',   150000),
(2022, 'Monitor',   80000),
(2022, 'Keyboard',  25000),
(2023, 'Laptop',   175000),
(2023, 'Monitor',   95000),
(2023, 'Keyboard',  30000),
(2023, 'Webcam',    40000);

GO

-- ==========================================
-- Problem 13: DimCustomer & CustomerStaging
-- ==========================================
CREATE TABLE DimCustomer (
    CustomerKey  INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID   VARCHAR(50),
    CustomerName VARCHAR(100),
    Email        VARCHAR(100),
    IsActive     BIT,
    EffectiveDate DATE,
    ExpiryDate    DATE
);

INSERT INTO DimCustomer (CustomerID, CustomerName, Email, IsActive, EffectiveDate, ExpiryDate) VALUES
('C001', 'Alice Johnson',  'alice@old.com',       1, '2023-01-01', '9999-12-31'),
('C002', 'Bob Smith',      'bob@company.com',      1, '2023-01-01', '9999-12-31'),
('C003', 'Carol Williams', 'carol@company.com',    1, '2023-03-15', '9999-12-31');

CREATE TABLE CustomerStaging (
    CustomerID   VARCHAR(50) PRIMARY KEY,
    CustomerName VARCHAR(100),
    Email        VARCHAR(100)
);

INSERT INTO CustomerStaging (CustomerID, CustomerName, Email) VALUES
('C001', 'Alice Johnson', 'alice@new.com'),
('C002', 'Bob Smith',     'bob@company.com'),
('C004', 'David Brown',   'david@company.com');

GO

-- ==========================================
-- Problem 14: MonthlyRevenue
-- ==========================================
CREATE TABLE MonthlyRevenue (
    revenue_id   INT PRIMARY KEY,
    region       VARCHAR(50),
    report_month DATE,
    revenue      INT
);

INSERT INTO MonthlyRevenue VALUES
-- 2023 data (Q1: MoM analysis)
( 1, 'North', '2023-01-01', 120000),
( 2, 'North', '2023-02-01', 135000),
( 3, 'North', '2023-03-01', 128000),
( 4, 'North', '2023-04-01', 142000),
( 5, 'South', '2023-01-01',  90000),
( 6, 'South', '2023-02-01',  87000),
( 7, 'South', '2023-03-01',  95000),
( 8, 'South', '2023-04-01', 101000),
-- 2022 data (Q2: YoY decline analysis)
( 9, 'North', '2022-01-01', 115000),
(10, 'North', '2022-02-01', 130000),
(11, 'North', '2022-03-01', 131000),
(12, 'North', '2022-04-01', 143000); -- Apr 2022 (143k) > Apr 2023 (142k) → decline

GO

-- ==========================================
-- Problem 15: No new tables
-- (reuses Employees from Problem 2)
-- UDFs are created inside the problem solutions themselves.
-- ==========================================

-- ==========================================
-- Problem 16: No new tables
-- (reuses Employees from Problem 2)
-- ==========================================

-- ==========================================
-- Problem 17: SourceOrders & TargetOrders
-- ==========================================
CREATE TABLE SourceOrders (
    order_id    INT PRIMARY KEY,
    customer_id VARCHAR(10),
    order_date  DATE,
    amount      INT,
    status      VARCHAR(20)
);

INSERT INTO SourceOrders VALUES
(1001, 'C01', '2023-10-01', 500, 'Complete'),
(1002, 'C02', '2023-10-01', 300, 'Complete'),  -- correct amount = 300
(1003, 'C03', '2023-10-02', 750, 'Pending'),   -- intentionally MISSING from target
(1004, 'C01', '2023-10-02', 200, 'Complete'),
(1005, 'C04', '2023-10-03', 420, 'Complete');

CREATE TABLE TargetOrders (
    order_id    INT PRIMARY KEY,
    customer_id VARCHAR(10),
    order_date  DATE,
    amount      INT,
    status      VARCHAR(20)
);

INSERT INTO TargetOrders VALUES
(1001, 'C01', '2023-10-01', 500, 'Complete'),
(1002, 'C02', '2023-10-01', 350, 'Complete'),  -- BUG: amount should be 300
-- 1003 omitted intentionally
(1004, 'C01', '2023-10-02', 200, 'Complete'),
(1005, 'C04', '2023-10-03', 420, 'Complete');

GO

-- ==========================================
-- Problem 18: Star Schema
-- ==========================================
CREATE TABLE DimDate (
    date_key   INT PRIMARY KEY,
    full_date  DATE,
    year       INT,
    quarter    INT,
    month      INT,
    month_name VARCHAR(20)
);

INSERT INTO DimDate VALUES
(20231001, '2023-10-01', 2023, 4, 10, 'October'),
(20231015, '2023-10-15', 2023, 4, 10, 'October'),
(20231201, '2023-12-01', 2023, 4, 12, 'December');

CREATE TABLE DimProduct (
    product_key  INT PRIMARY KEY,
    product_name VARCHAR(100),
    category     VARCHAR(50),
    subcategory  VARCHAR(50)
);

INSERT INTO DimProduct VALUES
(101, 'Laptop Pro',  'Electronics', 'Computers'),
(102, 'Wireless KB', 'Electronics', 'Peripherals'),
(103, 'Desk Chair',  'Furniture',   'Seating');

CREATE TABLE DimStore (
    store_key  INT PRIMARY KEY,
    store_name VARCHAR(100),
    region     VARCHAR(50)
);

INSERT INTO DimStore VALUES
(10, 'Sydney CBD',   'NSW'),
(20, 'Melbourne CC', 'VIC');

CREATE TABLE FactSales (
    sale_key     INT PRIMARY KEY,
    date_key     INT,
    product_key  INT,
    customer_key INT,
    store_key    INT,
    quantity     INT,
    unit_price   DECIMAL(10,2),
    discount     DECIMAL(5,2)
);

INSERT INTO FactSales VALUES
(1, 20231001, 101, 501, 10, 2, 1500.00, 0.10),
(2, 20231001, 102, 502, 10, 1,  800.00, 0.00),
(3, 20231015, 101, 501, 20, 1, 1500.00, 0.05),
(4, 20231201, 103, 503, 10, 3,  200.00, 0.00),
(5, 20231201, 102, 502, 20, 2,  800.00, 0.15);

GO

-- ==========================================
-- Problem 19: Orders (index demo)
-- ==========================================
CREATE TABLE Orders (
    order_id     INT IDENTITY(1,1) PRIMARY KEY,  -- clustered index by default
    customer_id  VARCHAR(10)   NOT NULL,
    order_date   DATE          NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL
);

INSERT INTO Orders (customer_id, order_date, total_amount) VALUES
('C0042', '2023-01-15', 1200.00),
('C0001', '2023-02-20',  450.00),
('C0042', '2023-03-10',  890.00),
('C0099', '2022-12-01',  300.00),
('C0042', '2022-11-05',  750.00),
('C0001', '2023-04-01',  620.00),
('C0042', '2023-05-22', 2100.00);

-- Uncomment below AFTER running the slow query to compare execution plans:
-- CREATE NONCLUSTERED INDEX IX_Orders_CustomerId_OrderDate
-- ON Orders (customer_id, order_date)
-- INCLUDE (total_amount);

GO

-- ==========================================
-- Problem 20: DailyRevenue
-- ==========================================
IF OBJECT_ID('DailyRevenue', 'U') IS NOT NULL DROP TABLE DailyRevenue;

CREATE TABLE DailyRevenue (
    date DATE PRIMARY KEY,
    revenue INT
);

INSERT INTO DailyRevenue (date, revenue) VALUES
('2023-11-01', 1500),
('2023-11-02', 2000),
('2023-11-03', 2500),
('2023-11-04', 1800),
('2023-11-05', 2200),
('2023-11-06', 3000);

GO

-- ==========================================
-- Problem 21: Departments
-- ==========================================
IF OBJECT_ID('Departments', 'U') IS NOT NULL DROP TABLE Departments;

CREATE TABLE Departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100)
);

INSERT INTO Departments (department_id, department_name) VALUES
(1, 'Engineering'),
(2, 'Marketing'),
(3, 'Sales');

GO

-- ==========================================
-- Problem 22: Candidates and RequiredSkills
-- ==========================================
IF OBJECT_ID('Candidates', 'U') IS NOT NULL DROP TABLE Candidates;
IF OBJECT_ID('RequiredSkills', 'U') IS NOT NULL DROP TABLE RequiredSkills;

CREATE TABLE Candidates (
    candidate_id INT,
    skill VARCHAR(50)
);

INSERT INTO Candidates (candidate_id, skill) VALUES
(101, 'Python'),
(101, 'SQL'),
(101, 'PowerBI'),
(102, 'SQL'),
(102, 'Tableau'),
(103, 'Python'),
(103, 'SQL');

CREATE TABLE RequiredSkills (
    required_skill VARCHAR(50)
);

INSERT INTO RequiredSkills (required_skill) VALUES
('SQL'),
('Python');

GO

-- ==========================================
-- Problem 23: OrderDetails
-- ==========================================
IF OBJECT_ID('OrderDetails', 'U') IS NOT NULL DROP TABLE OrderDetails;

CREATE TABLE OrderDetails (
    order_id INT,
    product_name VARCHAR(100)
);

INSERT INTO OrderDetails (order_id, product_name) VALUES
(1, 'Apple'),
(1, 'Banana'),
(1, 'Cherry'),
(2, 'Apple'),
(2, 'Banana'),
(3, 'Banana'),
(3, 'Cherry');

GO

-- ==========================================
-- Problem 24: Promotions
-- ==========================================
IF OBJECT_ID('Promotions', 'U') IS NOT NULL DROP TABLE Promotions;

CREATE TABLE Promotions (
    promo_id INT PRIMARY KEY,
    start_date DATE,
    end_date DATE
);

INSERT INTO Promotions (promo_id, start_date, end_date) VALUES
(1, '2023-01-01', '2023-01-10'),
(2, '2023-01-05', '2023-01-15'),
(3, '2023-01-20', '2023-01-25'),
(4, '2023-01-22', '2023-01-30');

GO

-- ==========================================
-- Problem 25: SalaryPeers
-- ==========================================
IF OBJECT_ID('SalaryPeers', 'U') IS NOT NULL DROP TABLE SalaryPeers;

CREATE TABLE SalaryPeers (
    name VARCHAR(100) PRIMARY KEY,
    salary INT
);

INSERT INTO SalaryPeers (name, salary) VALUES
('Alice', 50000),
('Bob', 50500),
('Charlie', 51500),
('David', 60000);

GO

-- ==========================================
-- Problem 26: PlayerScores (ROWS vs RANGE with Ties)
-- ==========================================
IF OBJECT_ID('PlayerScores', 'U') IS NOT NULL DROP TABLE PlayerScores;

CREATE TABLE PlayerScores (
    id INT IDENTITY(1,1) PRIMARY KEY,
    score_date DATE,
    points INT
);

INSERT INTO PlayerScores (score_date, points) VALUES
('2023-01-01', 10),
('2023-01-02', 15),
('2023-01-02', 5),
('2023-01-03', 20);

GO

-- ==========================================
-- Problem 27: Department Top Three Salaries
-- ==========================================
IF OBJECT_ID('Employee_LC', 'U') IS NOT NULL DROP TABLE Employee_LC;
IF OBJECT_ID('Department_LC', 'U') IS NOT NULL DROP TABLE Department_LC;

CREATE TABLE Department_LC (
    id INT PRIMARY KEY,
    name VARCHAR(50)
);

CREATE TABLE Employee_LC (
    id INT PRIMARY KEY,
    name VARCHAR(50),
    salary INT,
    departmentId INT FOREIGN KEY REFERENCES Department_LC(id)
);

INSERT INTO Department_LC (id, name) VALUES
(1, 'IT'),
(2, 'Sales');

INSERT INTO Employee_LC (id, name, salary, departmentId) VALUES
(1, 'Joe', 85000, 1),
(2, 'Henry', 80000, 2),
(3, 'Sam', 60000, 2),
(4, 'Max', 90000, 1),
(5, 'Janet', 69000, 1),
(6, 'Randy', 85000, 1),
(7, 'Will', 70000, 1);

GO

-- ==========================================
-- Problem 28: Human Traffic of Stadium
-- ==========================================
IF OBJECT_ID('Stadium', 'U') IS NOT NULL DROP TABLE Stadium;

CREATE TABLE Stadium (
    id INT PRIMARY KEY,
    visit_date DATE,
    people INT
);

INSERT INTO Stadium (id, visit_date, people) VALUES
(1, '2017-01-01', 10),
(2, '2017-01-02', 109),
(3, '2017-01-03', 150),
(4, '2017-01-04', 99),
(5, '2017-01-05', 145),
(6, '2017-01-06', 1455),
(7, '2017-01-07', 199),
(8, '2017-01-09', 188);

GO

-- ==========================================
-- Problem 29: Exchange Seats
-- ==========================================
IF OBJECT_ID('Seat', 'U') IS NOT NULL DROP TABLE Seat;

CREATE TABLE Seat (
    id INT PRIMARY KEY,
    student VARCHAR(50)
);

INSERT INTO Seat (id, student) VALUES
(1, 'Abbot'),
(2, 'Doris'),
(3, 'Emerson'),
(4, 'Green'),
(5, 'Jeames');

GO

-- ==========================================
-- Problem 30: Trips and Users
-- ==========================================
IF OBJECT_ID('Trips', 'U') IS NOT NULL DROP TABLE Trips;
IF OBJECT_ID('Users_LC', 'U') IS NOT NULL DROP TABLE Users_LC;

CREATE TABLE Users_LC (
    users_id INT PRIMARY KEY,
    banned VARCHAR(10),
    role VARCHAR(20)
);

CREATE TABLE Trips (
    id INT PRIMARY KEY,
    client_id INT,
    driver_id INT,
    city_id INT,
    status VARCHAR(50),
    request_at DATE
);

INSERT INTO Users_LC (users_id, banned, role) VALUES
(1, 'No', 'client'),
(2, 'Yes', 'client'),
(3, 'No', 'client'),
(4, 'No', 'client'),
(10, 'No', 'driver'),
(11, 'No', 'driver'),
(12, 'No', 'driver'),
(13, 'No', 'driver');

INSERT INTO Trips (id, client_id, driver_id, city_id, status, request_at) VALUES
(1, 1, 10, 1, 'completed', '2013-10-01'),
(2, 2, 11, 1, 'cancelled_by_driver', '2013-10-01'),
(3, 3, 12, 6, 'completed', '2013-10-01'),
(4, 4, 13, 6, 'cancelled_by_client', '2013-10-01'),
(5, 1, 10, 1, 'completed', '2013-10-02'),
(6, 2, 11, 6, 'completed', '2013-10-02'),
(7, 3, 12, 6, 'completed', '2013-10-02'),
(8, 2, 12, 12, 'completed', '2013-10-03'),
(9, 3, 10, 12, 'completed', '2013-10-03'),
(10, 4, 13, 12, 'cancelled_by_driver', '2013-10-03');

GO

-- ==========================================
-- Problem 31: Consecutive Numbers
-- ==========================================
IF OBJECT_ID('Logs', 'U') IS NOT NULL DROP TABLE Logs;

CREATE TABLE Logs (
    id INT PRIMARY KEY,
    num INT
);

INSERT INTO Logs (id, num) VALUES
(1, 1),
(2, 1),
(3, 1),
(4, 2),
(5, 1),
(6, 2),
(7, 2);

GO

-- ==========================================
-- Problem 32: Game Play Analysis IV
-- ==========================================
IF OBJECT_ID('Activity', 'U') IS NOT NULL DROP TABLE Activity;

CREATE TABLE Activity (
    player_id INT,
    device_id INT,
    event_date DATE,
    games_played INT,
    PRIMARY KEY (player_id, event_date)
);

INSERT INTO Activity (player_id, device_id, event_date, games_played) VALUES
(1, 2, '2016-03-01', 5),
(1, 2, '2016-03-02', 6),
(2, 3, '2017-06-25', 1),
(3, 1, '2016-03-02', 0),
(3, 4, '2018-07-03', 5);

GO

-- ==========================================
-- Problem 33: Tree Node
-- ==========================================
IF OBJECT_ID('Tree', 'U') IS NOT NULL DROP TABLE Tree;

CREATE TABLE Tree (
    id INT PRIMARY KEY,
    p_id INT
);

INSERT INTO Tree (id, p_id) VALUES
(1, NULL),
(2, 1),
(3, 1),
(4, 2),
(5, 2);

GO

-- ==========================================
-- Problem 34: Average Salary: Departments VS Company
-- ==========================================
IF OBJECT_ID('Salary_DP', 'U') IS NOT NULL DROP TABLE Salary_DP;
IF OBJECT_ID('Employee_DP', 'U') IS NOT NULL DROP TABLE Employee_DP;

CREATE TABLE Salary_DP (
    id INT PRIMARY KEY,
    employee_id INT,
    amount INT,
    pay_date DATE
);

CREATE TABLE Employee_DP (
    employee_id INT PRIMARY KEY,
    department_id INT
);

INSERT INTO Salary_DP (id, employee_id, amount, pay_date) VALUES
(1, 1, 9000, '2017-03-31'),
(2, 2, 6000, '2017-03-31'),
(3, 3, 10000, '2017-03-31'),
(4, 1, 7000, '2017-02-28'),
(5, 2, 6000, '2017-02-28'),
(6, 3, 8000, '2017-02-28');

INSERT INTO Employee_DP (employee_id, department_id) VALUES
(1, 1),
(2, 2),
(3, 2);

GO

-- ==========================================
-- Problem 35: Investments in 2016
-- ==========================================
IF OBJECT_ID('Insurance', 'U') IS NOT NULL DROP TABLE Insurance;

CREATE TABLE Insurance (
    pid INT PRIMARY KEY,
    tiv_2015 FLOAT,
    tiv_2016 FLOAT,
    lat FLOAT,
    lon FLOAT
);

INSERT INTO Insurance (pid, tiv_2015, tiv_2016, lat, lon) VALUES
(1, 10, 5, 10, 10),
(2, 20, 20, 20, 20),
(3, 10, 30, 20, 20),
(4, 10, 40, 40, 40);

GO

-- ==========================================
-- Problem 36: Active Businesses
-- ==========================================
IF OBJECT_ID('Events', 'U') IS NOT NULL DROP TABLE Events;

CREATE TABLE Events (
    business_id INT,
    event_type VARCHAR(50),
    occurences INT
);

INSERT INTO Events (business_id, event_type, occurences) VALUES
(1, 'reviews', 7),
(3, 'reviews', 3),
(1, 'ads', 11),
(2, 'ads', 7),
(3, 'ads', 6),
(1, 'page views', 3),
(2, 'page views', 12);

GO

-- ==========================================
-- Problem 37: Students Report By Geography
-- ==========================================
IF OBJECT_ID('Student', 'U') IS NOT NULL DROP TABLE Student;

CREATE TABLE Student (
    name VARCHAR(50),
    continent VARCHAR(50)
);

INSERT INTO Student (name, continent) VALUES
('Jane', 'America'),
('Pascal', 'Europe'),
('Xi', 'Asia'),
('Jack', 'America');

GO

-- ==========================================
-- Problem 38 & 39: Employee Hierarchy / Nth Highest Salary
-- ==========================================
IF OBJECT_ID('Employee_HR', 'U') IS NOT NULL DROP TABLE Employee_HR;

CREATE TABLE Employee_HR (
    id INT PRIMARY KEY,
    name VARCHAR(50),
    salary INT,
    managerId INT
);

INSERT INTO Employee_HR (id, name, salary, managerId) VALUES
(101, 'John', 100000, NULL),
(102, 'Dan', 80000, 101),
(103, 'James', 75000, 101),
(104, 'Amy', 90000, 101),
(105, 'Anne', 60000, 101),
(106, 'Ron', 55000, 101);

GO

-- ==========================================
-- Problem 40: Rank Scores
-- ==========================================
IF OBJECT_ID('Scores', 'U') IS NOT NULL DROP TABLE Scores;

CREATE TABLE Scores (
    id INT PRIMARY KEY,
    score DECIMAL(3,2)
);

INSERT INTO Scores (id, score) VALUES
(1, 3.50),
(2, 3.65),
(3, 4.00),
(4, 3.85),
(5, 4.00),
(6, 3.65);

GO

-- ==========================================
-- Problem 41: Rising Temperature
-- ==========================================
IF OBJECT_ID('Weather', 'U') IS NOT NULL DROP TABLE Weather;

CREATE TABLE Weather (
    id INT PRIMARY KEY,
    recordDate DATE,
    temperature INT
);

INSERT INTO Weather (id, recordDate, temperature) VALUES
(1, '2015-01-01', 10),
(2, '2015-01-02', 25),
(3, '2015-01-03', 20),
(4, '2015-01-04', 30);

GO

-- ==========================================
-- Problem 42: Capital Gain/Loss
-- ==========================================
IF OBJECT_ID('Stocks', 'U') IS NOT NULL DROP TABLE Stocks;

CREATE TABLE Stocks (
    stock_name VARCHAR(50),
    operation VARCHAR(10),
    operation_day INT,
    price INT
);

INSERT INTO Stocks (stock_name, operation, operation_day, price) VALUES
('Leetcode', 'Buy', 1, 1000),
('Corona Masks', 'Buy', 2, 10),
('Leetcode', 'Sell', 5, 9000),
('Handbags', 'Buy', 17, 30000),
('Corona Masks', 'Sell', 3, 1010),
('Corona Masks', 'Buy', 4, 1000),
('Corona Masks', 'Sell', 5, 500),
('Corona Masks', 'Buy', 6, 1000),
('Handbags', 'Sell', 29, 7000),
('Corona Masks', 'Sell', 10, 10000);

GO

-- ==========================================
-- Problem 43: Average Time of Process per Machine
-- ==========================================
IF OBJECT_ID('MachineActivity', 'U') IS NOT NULL DROP TABLE MachineActivity;

CREATE TABLE MachineActivity (
    machine_id INT,
    process_id INT,
    activity_type VARCHAR(10),
    timestamp FLOAT
);

INSERT INTO MachineActivity (machine_id, process_id, activity_type, timestamp) VALUES
(1, 1, 'start', 0.712),
(1, 1, 'end', 1.520),
(1, 2, 'start', 3.140),
(1, 2, 'end', 4.120),
(2, 1, 'start', 2.500),
(2, 1, 'end', 5.000),
(2, 2, 'start', 2.500),
(2, 2, 'end', 3.000);

GO

-- ==========================================
-- Problem 44: Apples & Oranges
-- ==========================================
IF OBJECT_ID('FruitSales', 'U') IS NOT NULL DROP TABLE FruitSales;

CREATE TABLE FruitSales (
    sale_date DATE,
    fruit VARCHAR(20),
    sold_num INT
);

INSERT INTO FruitSales (sale_date, fruit, sold_num) VALUES
('2020-05-01', 'apples', 10),
('2020-05-01', 'oranges', 8),
('2020-05-02', 'apples', 15),
('2020-05-02', 'oranges', 15),
('2020-05-03', 'apples', 20),
('2020-05-03', 'oranges', 0),
('2020-05-04', 'apples', 15),
('2020-05-04', 'oranges', 16);

GO

-- ==========================================
-- Problem 45: Find Median Given Frequency of Numbers
-- ==========================================
IF OBJECT_ID('Numbers', 'U') IS NOT NULL DROP TABLE Numbers;

CREATE TABLE Numbers (
    num INT PRIMARY KEY,
    frequency INT
);

INSERT INTO Numbers (num, frequency) VALUES
(0, 7),
(1, 1),
(2, 3),
(3, 1);

GO
