-- Drop tables if they already exist to make the script re-runnable
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
-- BillOfMaterials is dropped before its creation block

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
(1, 'Server_A', 'Online', '2023-10-01 10:00:00'),
(2, 'Server_A', 'Online', '2023-10-01 10:15:00'),
(3, 'Server_A', 'Offline', '2023-10-01 10:30:00'),
(4, 'Server_A', 'Offline', '2023-10-01 10:45:00'),
(5, 'Server_A', 'Offline', '2023-10-01 11:00:00'),
(6, 'Server_A', 'Online', '2023-10-01 11:15:00'),
(7, 'Server_B', 'Online', '2023-10-01 10:00:00'),
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
(1, 'Alice Turner', 'Engineering', 90000),
(2, 'Bob Chen', 'Engineering', 110000),
(3, 'Carol White', 'Engineering', 95000),
(4, 'David Kim', 'Engineering', 80000),
(5, 'Eva Green', 'Engineering', 105000),
(6, 'Frank Lopez', 'Sales', 55000),
(7, 'Grace Hall', 'Sales', 60000),
(8, 'Henry Scott', 'Sales', 55000),
(9, 'Isla Brown', 'Sales', 72000);

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
(2022, 'Laptop', 150000),
(2022, 'Monitor', 80000),
(2022, 'Keyboard', 25000),
(2023, 'Laptop', 175000),
(2023, 'Monitor', 95000),
(2023, 'Keyboard', 30000),
(2023, 'Webcam', 40000);

GO

-- ==========================================
-- Problem 13: DimCustomer & CustomerStaging
-- ==========================================
CREATE TABLE DimCustomer (
    CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID VARCHAR(50),
    CustomerName VARCHAR(100),
    Email VARCHAR(100),
    IsActive BIT,
    EffectiveDate DATE,
    ExpiryDate DATE
);

INSERT INTO DimCustomer (CustomerID, CustomerName, Email, IsActive, EffectiveDate, ExpiryDate) VALUES
('C001', 'Alice Johnson', 'alice@old.com', 1, '2023-01-01', '9999-12-31'),
('C002', 'Bob Smith', 'bob@company.com', 1, '2023-01-01', '9999-12-31'),
('C003', 'Carol Williams', 'carol@company.com', 1, '2023-03-15', '9999-12-31');

CREATE TABLE CustomerStaging (
    CustomerID VARCHAR(50) PRIMARY KEY,
    CustomerName VARCHAR(100),
    Email VARCHAR(100)
);

INSERT INTO CustomerStaging (CustomerID, CustomerName, Email) VALUES
('C001', 'Alice Johnson', 'alice@new.com'),
('C002', 'Bob Smith', 'bob@company.com'),
('C004', 'David Brown', 'david@company.com');

GO
