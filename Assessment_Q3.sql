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
