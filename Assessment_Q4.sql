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
        
        -- Calculate estimated CLV: (monthly transaction rate) × 12 months × average profit per transaction
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
