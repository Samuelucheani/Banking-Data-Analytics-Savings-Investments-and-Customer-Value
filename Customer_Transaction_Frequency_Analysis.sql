-- Create a CTE to calculate each customer's total transactions and how long they've been active
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
