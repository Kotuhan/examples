# examples

Some examples of my code-style

## SQL Repository Example

### Overview

The `sql/repository.ts` file demonstrates a NestJS repository implementation with complex SQL query optimization techniques. This example showcases how to handle multiple search scenarios efficiently while dealing with multi-table joins and pagination.

### Performance Metrics

- **Database Scale**: 10+ million records
- **Query Performance**: ~300ms response time
- **Dynamic Filtering**: Handles multiple filter combinations without performance degradation

### Key Features

**1. Adaptive Query Strategy**

- Implements three different query approaches based on filter conditions
- Uses empty filter optimization to avoid unnecessary joins
- Falls back to unlinked user search when no results found

**2. Dynamic SQL Query Construction**

- Conditionally builds SQL queries based on provided filters
- Uses Common Table Expressions (CTEs) for better query organization
- Leverages PostgreSQL-specific features like `array_agg` for data aggregation

**3. Performance Optimization**

- Defers expensive JOINs until after pagination is applied
- Pre-filters data using CTEs before joining multiple tables
- Searches across multiple tables (Users and TransactionPaypalData) efficiently using UNION

**4. Type Safety**

- Uses TypeScript for strong typing throughout
- Defines clear parameter types and return types
- Transforms raw query results to domain models

### Code Highlights

#### Multi-table Email Search

The repository searches for users by email across two different tables:

- Direct match in `Users.email`
- Match in `TransactionPaypalData.payerEmail` (requiring multiple table joins)

#### Two-stage Query Pattern

```
Stage 1: Filter and paginate → Get small set of user IDs
Stage 2: Join with related tables → Enrich data for the filtered users
```

This approach significantly improves performance by reducing the number of rows that undergo expensive JOIN operations.

#### Unlinked User Detection

Includes special logic to detect if a user exists but is marked as unlinked, providing better user feedback when searches return no results.

### Database Optimization Strategy

#### Index Configuration

The database schema (see `schema.prisma`) includes strategic indexes that enable the high-performance queries:

**Users Table Indexes:**

- `email_idx` - Standard B-tree index for exact email lookups
- `users_email_gin_idx` - GIN (Generalized Inverted Index) with `gin_trgm_ops` for fuzzy LIKE searches using PostgreSQL's pg_trgm extension
- `users_created_at_idx` - Supports efficient date range filtering and sorting
- `isUserUnlinked_idx` - Fast filtering of linked/unlinked users

**TransactionPaypalData Table Indexes:**

- `transaction_paypal_data_email_idx` - Standard B-tree index for exact matches
- `transaction_paypal_data_payer_email_gin_idx` - GIN index with trigram support for partial email matching

**CounterParties Table Indexes:**

- `userId` - Enables fast JOIN operations when traversing from Users to Orders

**Orders Table Indexes:**

- `counterPartyId` - Critical for JOIN performance when linking users to their orders
- `createdAt` - Supports date-based filtering and ORDER BY operations

#### Why These Indexes Matter

1. **GIN Indexes with pg_trgm**: Enable ultra-fast LIKE queries with leading wildcards (e.g., `email LIKE 'john%'`), which are typically slow with standard B-tree indexes

2. **Compound Strategy**: Combines exact match indexes (B-tree) for equality searches with fuzzy match indexes (GIN) for partial text searches

3. **JOIN Optimization**: Strategic foreign key indexes (`userId`, `counterPartyId`) ensure the multi-table joins in CTEs execute efficiently

4. **Sort Performance**: `createdAt` indexes allow PostgreSQL to return sorted results without expensive in-memory sorting operations

This index strategy is crucial for achieving ~300ms query times on a 10M+ record database with dynamic filtering.

#### Note on Full-Text Search Implementation

While dedicated full-text search solutions like Elasticsearch or Algolia would typically be preferred for complex text search scenarios, this implementation uses PostgreSQL's native pg_trgm extension as a pragmatic solution. This approach was chosen based on:

- Existing PostgreSQL infrastructure
- Avoiding additional service dependencies
- Acceptable performance for the use case (~300ms)
- Simplified deployment and maintenance

The trigram-based GIN indexes provide sufficient performance for partial email matching without introducing external search infrastructure.

### Technologies

- NestJS with Dependency Injection
- Prisma ORM (`$queryRawUnsafe` for raw SQL)
- PostgreSQL with pg_trgm extension
- TypeScript
- class-validator for email validation
