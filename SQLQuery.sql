-- =========================================================================
-- STEP 1: DATABASE SETUP & RELATION SCHEMA (ERD)
-- =========================================================================
CREATE DATABASE CzechoslovakiaBank;
GO
USE CzechoslovakiaBank;
GO

-- 1. District Dimension Table
CREATE TABLE District (
    district_id INT PRIMARY KEY,
    district_name VARCHAR(100),
    region VARCHAR(100),
    population INT,
    a5 INT, a6 INT, a7 INT, a8 INT, -- Municipality statistics
    num_cities INT,
    urban_ratio DECIMAL(5,2),
    avg_salary INT,
    unemployment_95 DECIMAL(5,2),
    unemployment_96 DECIMAL(5,2),
    entrepreneurs_per_1000 INT,
    crimes_95 INT,
    crimes_96 INT
);

-- 2. Account Dimension Table
CREATE TABLE Account (
    account_id INT PRIMARY KEY,
    district_id INT FOREIGN KEY REFERENCES District(district_id),
    frequency VARCHAR(50),
    open_date_raw INT, -- Stored as raw YYMMDD initially
    account_type VARCHAR(50)
);

-- 3. Client Dimension Table
CREATE TABLE Client (
    client_id INT PRIMARY KEY,
    birth_number VARCHAR(50),
    district_id INT
);


-- 4. Disposition Bridge Table
CREATE TABLE Disposition (
    disp_id INT PRIMARY KEY,
    client_id INT FOREIGN KEY REFERENCES Client(client_id),
    account_id INT FOREIGN KEY REFERENCES Account(account_id),
    type VARCHAR(20)
);

-- 5. Card Dimension Table
CREATE TABLE Card (
    card_id INT PRIMARY KEY,
    disp_id INT FOREIGN KEY REFERENCES Disposition(disp_id),
    type VARCHAR(20),
    issued_raw VARCHAR(50) -- Raw text timestamp
);

-- 6. Loan Fact Table
CREATE TABLE Loan (
    loan_id INT PRIMARY KEY,
    account_id INT FOREIGN KEY REFERENCES Account(account_id),
    date_raw INT,
    amount DECIMAL(18,2),
    duration INT,
    payments DECIMAL(18,2),
    status CHAR(1) -- A, B, C, D
);

-- 7. Order Fact Table
CREATE TABLE PaymentOrder (
    order_id INT PRIMARY KEY,
    account_id INT FOREIGN KEY REFERENCES Account(account_id),
    bank_to VARCHAR(100),
    account_to BIGINT,
    amount DECIMAL(18,2)
);

-- 8. Staging Transaction Fact Table (Consolidates 2016, 2017, 2018)
CREATE TABLE FinancialTransaction (
    trans_id INT PRIMARY KEY,
    account_id INT FOREIGN KEY REFERENCES Account(account_id),
    date_raw DATE,
    type VARCHAR(20),
    operation VARCHAR(100),
    amount DECIMAL(18,2),
    balance DECIMAL(18,2),
    purpose VARCHAR(100),
    bank VARCHAR(100),
    account_partner_id VARCHAR(100)
);
GO

-- =========================================================================
-- INGESTION TEMPLATE (BULK INSERT)
-- Adjust paths below to point to your physical file locations on the machine.
-- =========================================================================
-- 1. Ingest Accounts
BULK INSERT Account FROM 'C:\Users\DELL\Desktop\Analytix Labs INternship\Week 2\PRP Project-1\1. Data\account.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n');

-- 2. Ingest Clients (Notice FIELDTERMINATOR is ';' because client.csv is semicolon-separated)
BULK INSERT Client FROM 'C:\Users\DELL\Desktop\Analytix Labs INternship\Week 2\PRP Project-1\1. Data\client.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n');


-- 3. Ingest Dispositions
BULK INSERT Disposition FROM 'C:\Users\DELL\Desktop\Analytix Labs INternship\Week 2\PRP Project-1\1. Data\disp.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n');

-- 4. Ingest Cards (Notice FIELDTERMINATOR is ';' because card.csv is semicolon-separated)
BULK INSERT Card FROM 'C:\Users\DELL\Desktop\Analytix Labs INternship\Week 2\PRP Project-1\1. Data\card.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ';', ROWTERMINATOR = '\n');

-- 5. Ingest Loans
BULK INSERT Loan FROM 'C:\Users\DELL\Desktop\Analytix Labs INternship\Week 2\PRP Project-1\1. Data\loan.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n');

-- 6. Ingest Payment Orders
BULK INSERT PaymentOrder FROM 'C:\Users\DELL\Desktop\Analytix Labs INternship\Week 2\PRP Project-1\1. Data\order.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n');

-- 7. Ingest All Transaction Histories into One Central Fact Table 
BULK INSERT FinancialTransaction FROM 'C:\Users\DELL\Desktop\Analytix Labs INternship\Week 2\PRP Project-1\1. Data\trnx_16.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n');

BULK INSERT FinancialTransaction FROM 'C:\Users\DELL\Desktop\Analytix Labs INternship\Week 2\PRP Project-1\1. Data\trnx_17.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n');

BULK INSERT FinancialTransaction FROM 'C:\Users\DELL\Desktop\Analytix Labs INternship\Week 2\PRP Project-1\1. Data\trnx_18.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n');

BULK INSERT FinancialTransaction FROM 'C:\Users\DELL\Desktop\Analytix Labs INternship\Week 2\PRP Project-1\1. Data\trnx_19_NEW.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n');

BULK INSERT FinancialTransaction FROM 'C:\Users\DELL\Desktop\Analytix Labs INternship\Week 2\PRP Project-1\1. Data\trnx_20_NEW.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n');

BULK INSERT FinancialTransaction FROM 'C:\Users\DELL\Desktop\Analytix Labs INternship\Week 2\PRP Project-1\1. Data\trnx_21_NEW.csv'
WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n');
GO

SELECT TOP 10 * FROM FinancialTransaction 
WHERE date_raw IS NOT NULL

SELECT * FROM FinancialTransaction

-- =========================================================================
-- STEP 2: DATA CLEANING & TRANSFORMATION
-- =========================================================================

--Step 1: Inspect the Raw Values
SELECT TOP 10 
    client_id, 
    birth_number,
    -- Let's see the length and structure
    LEN(birth_number) as string_len
FROM Client;

SELECT TOP 5 open_date_raw FROM Account;
SELECT TOP 5 date_raw FROM Loan;

--Step 2: Clean and Standardize the Client Table (Gender & Age)
-- 1. Add permanent clean columns to the Client table
ALTER TABLE Client ADD 
    BirthDate DATE,
    Gender VARCHAR(10),
    Age INT;
GO

-- 2. Extract Gender and Clean BirthDate
-- We parse the DD-MM-YYYY string. If MM > 50, it's Female and we subtract 50.
WITH ParsedClient AS (
    SELECT 
        client_id,
        CAST(SUBSTRING(birth_number, 1, 2) AS INT) as birth_day,
        CAST(SUBSTRING(birth_number, 4, 2) AS INT) as raw_month,
        -- Correct the year to standard 19xx format (handling the custom offsets)
        1900 + (CAST(SUBSTRING(birth_number, 7, 4) AS INT) % 100) as birth_year
    FROM Client
)
UPDATE c
SET 
    c.Gender = CASE WHEN p.raw_month > 50 THEN 'Female' ELSE 'Male' END,
    c.BirthDate = CASE 
        WHEN p.raw_month > 50 THEN DATEFROMPARTS(p.birth_year, p.raw_month - 50, p.birth_day)
        ELSE DATEFROMPARTS(p.birth_year, p.raw_month, p.birth_day)
    END
FROM Client c
JOIN ParsedClient p ON c.client_id = p.client_id;
GO

-- 3. Calculate Age (Assuming dataset analysis baseline year of 1999/2000 or current date)
UPDATE Client 
SET Age = DATEDIFF(YEAR, BirthDate, '1999-12-31'); 
GO

-- Verify the transformation
SELECT TOP 10 client_id, birth_number, BirthDate, Gender, Age FROM Client;





-- 1. Remove the old raw text columns to keep your database clean
ALTER TABLE Account DROP COLUMN open_date_raw;
ALTER TABLE Loan DROP COLUMN date_raw;
ALTER TABLE FinancialTransaction DROP COLUMN date_raw;

-- 2. Rename your new clean columns to the standard names
-- (If you named them TransactionDate, etc., you are good to go!)
EXEC sp_rename 'FinancialTransaction.TransactionDate', 'trans_date', 'COLUMN';
EXEC sp_rename 'Account.OpenDate', 'open_date', 'COLUMN';
EXEC sp_rename 'Loan.LoanDate', 'loan_date', 'COLUMN';

-- 3. Final sanity check on your counts
SELECT 'FinancialTransaction' AS TableName, COUNT(*) AS Row_Count FROM FinancialTransaction;


-----------------EDA----------------------------------
-- Analyze Customer Demographics (Gender & Age)
SELECT 
    Gender, 
    CASE 
        WHEN Age < 30 THEN 'Under 30'
        WHEN Age BETWEEN 30 AND 50 THEN '30-50'
        ELSE 'Above 50'
    END AS AgeGroup,
    COUNT(*) AS ClientCount
FROM Client
GROUP BY Gender, 
    CASE 
        WHEN Age < 30 THEN 'Under 30'
        WHEN Age BETWEEN 30 AND 50 THEN '30-50'
        ELSE 'Above 50'
    END
ORDER BY Gender, AgeGroup;

--Monthly Transaction Volume Trend
SELECT 
    FORMAT(trans_date, 'yyyy-MM') AS TransactionMonth, 
    COUNT(*) AS TotalTransactions,
    SUM(amount) AS TotalVolume
FROM FinancialTransaction
GROUP BY FORMAT(trans_date, 'yyyy-MM')
ORDER BY TransactionMonth;

--Loan Performance Summary
SELECT 
    status AS LoanStatus, 
    COUNT(*) AS LoanCount, 
    SUM(amount) AS TotalAmount
FROM Loan
GROUP BY status;



-- =========================================================================
-- STEP 4: 5 CORE EXECUTIVE KPI QUERIES
-- =========================================================================

-- KPI 1: Loan Portfolio At Risk (PAR) Rate
-- Definition: (Total Outstanding Principal of Bad/Defaulting Loans / Total Outstanding Portfolio Value) * 100
SELECT 
    SUM(CASE WHEN status IN ('B', 'D') THEN amount ELSE 0 END) AS Total_Portfolio_At_Risk,
    SUM(amount) AS Total_Active_Portfolio,
    ROUND((SUM(CASE WHEN status IN ('B', 'D') THEN amount ELSE 0 END) / SUM(amount)) * 100, 2) AS PAR_Percentage
FROM Loan;


-- KPI 2: Cross-Selling Ratio (Cards Per Account)
-- Definition: Count of issued debit/credit cards divided by total distinct base bank accounts
SELECT 
    (SELECT COUNT(*) FROM Account) AS Total_Base_Accounts,
    (SELECT COUNT(*) FROM Card) AS Total_Issued_Cards,
    ROUND(CAST((SELECT COUNT(*) FROM Card) AS DECIMAL(10,2)) / (SELECT COUNT(*) FROM Account), 4) AS Cross_Sell_Ratio;


-- KPI 3: Average Net Non-Cash Inflow Margin Per Transaction Account
-- Definition: Mean Net Difference between Total Credits and Total Withdrawals on account logs
SELECT 
    AVG(Net_Inflow) AS Avg_Net_Inflow_Per_Account
FROM (
    SELECT account_id,
           SUM(CASE WHEN type = 'Credit' THEN amount ELSE -amount END) AS Net_Inflow
    FROM FinancialTransaction
    GROUP BY account_id
) AS AccountMargins;


-- KPI 4: Month-over-Month Transaction Revenue Value Growth Rate
-- Definition: Evaluates transaction activity growth to track platform utilization velocity
WITH MonthlyTotals AS (
    SELECT YEAR(date_raw) as CalendarYear, MONTH(date_raw) as CalendarMonth, SUM(amount) as MonthlyVolume,
           LAG(SUM(amount)) OVER (ORDER BY YEAR(date_raw), MONTH(date_raw)) as PreviousMonthVolume
    FROM FinancialTransaction
    GROUP BY YEAR(date_raw), MONTH(date_raw)
)
SELECT CalendarYear, CalendarMonth, MonthlyVolume, PreviousMonthVolume,
       ROUND(((MonthlyVolume - PreviousMonthVolume) / PreviousMonthVolume) * 100, 2) AS Volume_MoM_Growth_Pct
FROM MonthlyTotals;


-- KPI 5: Customer Concentration Ratio by District Market Share Tier
-- Definition: Identifies top risk dependencies by examining the percentage distribution of total assets across geographic markets
SELECT TOP 5
    d.district_name,
    COUNT(DISTINCT a.account_id) as total_district_accounts,
    ROUND(COUNT(DISTINCT a.account_id) * 100.0 / (SELECT COUNT(*) FROM Account), 2) AS Market_Share_Account_Percentage
FROM Account a
JOIN District d ON a.district_id = d.district_id
GROUP BY d.district_name
ORDER BY Market_Share_Account_Percentage DESC;