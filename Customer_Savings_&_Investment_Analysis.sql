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
JOIN funded_investments fi ON u.id = fi.owner_id  -- Join customers with their funded investment data 
-- Sort by total deposit value from highest to lowest
ORDER BY total_deposits DESC;                        
  