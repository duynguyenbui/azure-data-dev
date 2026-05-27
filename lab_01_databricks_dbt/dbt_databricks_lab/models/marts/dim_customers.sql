with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customer_order_summary as (
    select
        customer_id,
        min(order_date)             as first_order_date,
        max(order_date)             as most_recent_order_date,
        count(order_id)             as number_of_orders,
        sum(total_amount)           as total_spent,
        avg(total_amount)           as avg_order_value
    from orders
    group by customer_id
),

final as (
    select
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        c.country,
        coalesce(s.first_order_date,       null)   as first_order_date,
        coalesce(s.most_recent_order_date, null)   as most_recent_order_date,
        coalesce(s.number_of_orders,       0)      as number_of_orders,
        coalesce(s.total_spent,            0.0)    as total_spent,
        coalesce(s.avg_order_value,        0.0)    as avg_order_value,
        case
            when coalesce(s.total_spent, 0) >= 400 then 'VIP'
            when coalesce(s.number_of_orders, 0) >= 2  then 'Regular'
            else 'New'
        end as customer_segment
    from customers c
    left join customer_order_summary s using (customer_id)
)

select * from final
