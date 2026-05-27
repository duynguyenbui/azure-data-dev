with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

final as (
    select
        o.order_id,
        o.customer_id,
        o.order_date,
        c.country               as customer_country,
        o.status,
        o.total_amount,
        case
            when o.total_amount >= 300 then 'High Value'
            when o.total_amount >= 100 then 'Mid Value'
            else 'Low Value'
        end as order_value_tier
    from orders o
    left join customers c using (customer_id)
)

select * from final
