with source as (
    select * from {{ source('default', 'raw_customers') }}
),

renamed as (
    select
        cast(customer_id as integer) as customer_id,
        first_name,
        last_name,
        lower(email) as email,
        country
    from source
    where customer_id is not null
)

select * from renamed
