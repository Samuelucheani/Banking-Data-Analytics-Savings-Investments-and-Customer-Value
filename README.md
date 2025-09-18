
#Customers with Both Savings and Investments

#Task: Find customers who have both a funded savings plan and a funded investment plan. We want to see their total deposits to identify high-value clients.

#SQL Summary:

```sql
-- Create a CTE (Common Table Expression) for all customers who have funded savings accounts
WITH funded_savings AS (
  SELECT 
    owner_id,  -- ID of the customers who own the savings account                            
    COUNT(*) AS savings_count,  -- Number of funded savings account customers own          
    SUM(amount) AS savings_total -- Total amount of money deposited across those accounts     
  FROM savings_savingsaccount
  WHERE amount > 0                       
  GROUP BY owner_id                      
),

-- Create a CTE for all users who have funded investment plans
funded_investments AS (
  SELECT 
    owner_id, -- ID of the customer who owns the investment plan                             
    COUNT(*) AS investment_count, -- Total number of funded investment plans        
    SUM(amount) AS investment_total  -- Total amount invested     
  FROM plans_plan
  WHERE amount > 0                        
  GROUP BY owner_id
)

-- Join the customer table with the funded_savings and funded_investments CTEs
SELECT 
  u.id AS owner_id,                                  
  CONCAT(u.first_name, ' ', u.last_name) AS name,    
  fs.savings_count,  -- Number of savings accounts(CTE)                               
  fi.investment_count, -- Number of investment plans(CTE)  
  -- To get total deposits
  (fs.savings_total + fi.investment_total) AS total_deposits  
FROM users_customuser u
JOIN funded_savings fs ON u.id = fs.owner_id -- Join customers to their funded savings data     
JOIN funded_investments fi ON u.id = fi.owner_id  -- Join customers to their funded investment data 
-- Sort by total deposit value from highest to lowest
ORDER BY total_deposits DESC; 
```

#Explanation of SQL Logic:

- `CTEs`: I used them to cleanly separate logic for savings and investment accounts. This keeps things readable and avoids repeating complex subqueries.
- `JOIN`: I want only customers who appear in both savings and investment CTEs. `JOIN` ensures this intersection.
- `GROUP BY`: Necessary to aggregate the number of accounts and total amount for each customer.

#Challenges:
- My inital query kept showing me lost connection to MYSQL Server.

- I had to break the logic into two Common Table Expressions (CTEs) (funded_savings and funded_investments) improving clarity and performance.

---

#Transaction Frequency

#Task: Segment customers by how often they transact. This helps us identify "frequent users" vs. those who rarely use their accounts.

#SQL Summary:

```sql
WITH customer_activity AS (
    SELECT 
        s.owner_id,  
        COUNT(*) AS total_transactions, -- Total number of transactions made by the customer
        TIMESTAMPDIFF(MONTH, MIN(s.transaction_date), CURDATE()) AS active_months
        -- Calculate how many months the customer has been active from their first transaction till date 
    FROM savings_savingsaccount s
    GROUP BY s.owner_id  
),

-- Use the results of the first CTE to categorize customers by activity frequency
categorized_activity AS (
    SELECT 
        ca.owner_id,
        (total_transactions /(active_months)) AS avg_txn_per_month,
        -- Calculate average transactions per month.
      
        CASE
            WHEN (total_transactions / (active_months)) >= 10 THEN 'High Frequency'
            -- Greater than or equal to 10 transactions per month (High frequency customer)

            WHEN (total_transactions / (active_months)) BETWEEN 3 AND 9 THEN 'Medium Frequency'
            -- Transactions between 3 and 9 (Moderately active customer)

            ELSE 'Low Frequency'
            -- Transactions Less than or equal to 2 (Low frequency customer)
        END AS frequency_category
    FROM customer_activity ca
)

-- Aggregate the frequency groups to get counts and average behavior
SELECT 
    frequency_category,  -- High frequency customer, Medium frequency customer, Low frequency customer
    COUNT(*) AS customer_count,  -- No of customers in each category
    ROUND(AVG(avg_txn_per_month), 1) AS avg_transactions_per_month  -- Average of average monthly transactions
FROM categorized_activity
GROUP BY frequency_category
ORDER BY FIELD(frequency_category, 'High Frequency', 'Medium Frequency', 'Low Frequency');
-- Rank the output in a custom way: High, then Medium, then Low
```

#Explanation of SQL Logic:

- `CTEs`: Again, using `WITH` blocks keeps our logic clean and separated. I first calculate monthly transaction counts, then average those counts, then categorize.
- `DATE_FORMAT`: I used this to simplify grouping by month.
- `CASE`: This is how we assign a label to each customer based on how active they are.

#Challenges:
- I used CTEs (customer_activity and categorized_activity) to break down logic and isolate errors step-by-step.

- Needed to enforce custom ordering (High, Medium, Low) using FIELD(),otherwise, SQL would sort alphabetically.
---

#Inactive Accounts

#Task: We want to identify active savings/investment accounts that have not received any deposits in the last 365 days.

#SQL Summary:

```sql
-- Find savings accounts with no inflow activity (deposit) in the last year
SELECT 
    sa.id AS plan_id, -- Unique ID of the savings account named as (plan_id)
    sa.owner_id, -- ID of the customer who owns the account
    'Savings' AS type, -- Name this row as(Savings)
    MAX(sa.transaction_date) AS last_transaction_date,  -- Most recent deposit that was made into this savings account
    DATEDIFF(CURDATE(), MAX(sa.transaction_date)) AS inactivity_days -- Calculate the number of days since the last deposit was made
FROM savings_savingsaccount sa
WHERE sa.transaction_type_id = 1  -- We're only interested in inflow (type_id = 1, typically means 'deposit')
GROUP BY sa.id, sa.owner_id       -- Group by each account so we can evaluate the last inflow separately
HAVING inactivity_days > 365      -- where the last deposit was made over a year ago

UNION

-- Find investment plans with no inflow in the last year
SELECT 
    pp.id AS plan_id, -- Unique ID of the investment plan
    pp.owner_id,                                 
    'Investment' AS type, -- Name this row as (Investment)
    MAX(pp.last_charge_date) AS last_transaction_date,  -- The last time a payment was made
    DATEDIFF(CURDATE(), MAX(pp.last_charge_date)) AS inactivity_days  -- Calculate how many days since the investment plan was last charged
FROM plans_plan pp
WHERE 
    pp.amount > 0                                
    AND pp.last_charge_date IS NOT NULL  -- To make sure there is a recorded charge date
GROUP BY pp.id, pp.owner_id
HAVING inactivity_days > 365  -- Only show plans with no inflow in over a year
```

#Explanation of SQL Logic:

- `DATEDIFF`: Tells us how many days since the last transaction/charge.
- `UNION`: I used this to combine two separate tables (`savings_savingsaccount` and `plans_plan`) into one result set.
- `HAVING`: Used here because we are filtering on a calculated field (`inactivity_days`).

#Challenges:
- I had to guess that transaction_type_id = 1 likely referred to deposit/inflow transactions.

- I used DATEDIFF(CURDATE(), MAX(...)) to calculate inactivity needed to apply the correct filtering after grouping, which required HAVING instead of WHERE.

- Combined savings and investments using UNION for a consolidated output.

---

#Customer Lifetime Value (CLV)

#Task: Estimate how valuable a customer is, based on how long they have been with us and how much they transact.

Formula:

CLV = (total_transactions / tenure_months) * 12 * avg_profit_per_transaction

Assume each transaction earns us 0.1% of its value.

#SQL Summary:

```sql
-- Summarize each customer's transaction history and account tenure
WITH customer_txn_summary AS (
    SELECT 
        u.id AS customer_id,  -- Unique ID for the customer
        CONCAT(u.first_name, ' ', u.last_name) AS name,  -- CONCAT to combine the customers first name and last name
        TIMESTAMPDIFF(MONTH, u.date_joined, CURDATE()) AS tenure_months,  -- Number of months since the customer signed up
        COUNT(s.id) AS total_transactions,  -- Total number of transactions linked to a customer
        SUM(s.confirmed_amount) AS total_value,  -- Total value of all confirmed transactions
        AVG(s.confirmed_amount) AS avg_transaction_value  -- Average value per transaction
    FROM users_customuser u
    JOIN savings_savingsaccount s ON s.owner_id = u.id  -- Join customers to their savings accounts
    GROUP BY u.id, u.first_name, u.last_name, u.date_joined  -- Group by customer so we can aggregate
),

-- Estimate Customer Lifetime Value (CLV) using a simplified formula
clv_calculated AS (
    SELECT 
        customer_id,
        name,
        tenure_months,
        total_transactions,
        
        -- Calculate estimated CLV: (monthly transaction rate) * 12 months * average profit per transaction
        -- where profit per transaction is 0.1% (0.001)
        ROUND(
            (total_transactions / (tenure_months)) * 12 * (0.001 * avg_transaction_value), 2
        ) AS estimated_clv
    FROM customer_txn_summary
)

-- Show final result ordered by most valuable customers
SELECT *
FROM clv_calculated
ORDER BY estimated_clv DESC;  -- Ranked from highest to lowest
```

#Explanation of SQL Logic:

- `DATEDIFF` and `TIMESTAMPDIFF`: Help me to calculate tenure in months from `date_joined`.
- `SUM(amount)`: To calculate total transaction value.

#Challenges:
- The CLV formula was custom and required combining multiple metrics, I separated calculations into two CTEs to keep things modular.

- confirmed_amount was used instead of amount, based on dataset semantics, meaning only approved transactions were considered.




