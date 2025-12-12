import { Injectable } from "@nestjs/common";
import { BaseRepository } from "../../common/db/base.repository";
import { UserFilters } from "./types/admin-filter";
import { ReadOnlyDatabaseService } from "../../common/db/readonly.db.service";
import { AdminUserDomainModel, AdminUserViewModel } from "./types/admin-user";
import { uniq } from "lodash";
import { isEmail } from "class-validator";

type GetUsersParams = {
  filters: UserFilters;
  pagination: { take: number; skip: number };
};

type QueryUser = AdminUserDomainModel & { payer_emails: Array<string | null> };

@Injectable()
export class AdminRepository extends BaseRepository {
  constructor(protected readonly databaseService: ReadOnlyDatabaseService) {
    super(databaseService);
  }

  public async getUsers(
    params: GetUsersParams
  ): Promise<{ isUserUnlinked: boolean; users: AdminUserViewModel[] }> {
    const isEmptyFilters = Object.values(params.filters).every(
      (filter) => !filter
    );

    // 1) If filters are empty, we can use a more efficient query
    if (isEmptyFilters) {
      const users = await this.getEmptyFiltersUsers(params.pagination);
      return { isUserUnlinked: false, users };
    }

    // 2) Get all users (only linked users)
    const users = await this.getUsersByQueryTemplate(params);

    if (users.length > 0) {
      return { isUserUnlinked: false, users };
    }

    // 3) If no linked users found, we check strictly for unlinked users by email or userId
    const isUserUnlinked = await this.checkIsUserUnlinked(
      params.filters.email,
      params.filters.userId
    );

    return {
      users: [],
      isUserUnlinked,
    };
  }

  private checkIsUserUnlinked = async (
    email: string | undefined,
    userId: number | undefined
  ) => {
    // Do not check if email is not valid and userId is not provided
    if (!isEmail(email) && !userId) {
      return false;
    }

    /* 
      $1 - email
      $2 - userId
    */

    const query = `
    WITH matched_users AS (
      SELECT DISTINCT U."userId" FROM "Users" U
          WHERE ${email ? `U."email" = $1` : ""}
          -- add OR to combine conditions
          ${email && userId ? "OR" : ""} ${userId ? `U."userId" = $2` : ""}
      ${
        email
          ? `
      UNION

      SELECT DISTINCT CP."userId" FROM "TransactionPaypalData" TPD -- by TransactionPaypalData.payerEmail
          JOIN "Transactions" T on T."transactionId" = TPD."transactionId"
          JOIN "Orders" O on O."orderId" = T."orderId"
          JOIN "CounterParties" CP on CP."counterPartyId" = O."counterPartyId"
      WHERE TPD."payerEmail" = $1`
          : ""
      }
  )
    SELECT * FROM "Users" U
        JOIN matched_users MU ON U."userId" = MU."userId"
    WHERE U."isUserUnlinked" = true;
    `;

    const emailParam = email || "";
    const userIdParam = Number(userId || 0);

    const matchCount = await this.databaseService.$queryRawUnsafe<[]>(
      query,
      emailParam,
      userIdParam
    );

    return matchCount.length > 0;
  };

  private getEmptyFiltersUsers = async ({
    take: limit,
    skip: offset,
  }: {
    take: number;
    skip: number;
  }): Promise<AdminUserDomainModel[]> => {
    /* 
      $1 - offset
      $2 - limit
    */

    const query = `
    WITH paginated_users AS (
      SELECT U."userId", U."createdAt", U."userId", U."email" FROM "Users" U
          WHERE U."isUserUnlinked" = false
        ORDER BY U."createdAt" DESC
        OFFSET $1
        LIMIT $2
    )
    SELECT U.*, array_agg(TPD."payerEmail") as payer_emails FROM paginated_users U
      LEFT JOIN "CounterParties" CP on U."userId" = CP."userId"
      LEFT JOIN "Orders" ON CP."counterPartyId" = "Orders"."counterPartyId"
      LEFT JOIN "Transactions" T ON "Orders"."orderId" = T."orderId"
      LEFT JOIN "TransactionPaypalData" TPD ON T."transactionId" = TPD."transactionId"
      GROUP BY U."userId", U."createdAt", U."userId", U."email"
      ORDER BY U."createdAt" DESC;
  `;

    const limitParam = Number(limit);
    const offsetParam = Number(offset);

    const results = await this.databaseService.$queryRawUnsafe<QueryUser[]>(
      query,
      offsetParam,
      limitParam
    );

    return results.map(AdminRepository.toDomainModel);
  };

  private getUsersByQueryTemplate = async ({
    filters,
    pagination,
  }: GetUsersParams): Promise<AdminUserDomainModel[]> => {
    const { take: limit, skip: offset } = pagination;
    const { email, userId, createdAtFrom, createdAtTo } = filters;

    /* 
      $1 - email
      $2 - userId
      $3 - createdAtFrom
      $4 - createdAtTo
      $5 - offset
      $6 - limit
    */

    const query = `
    WITH
    -- If email is provided, we need to efficiently search by email in two tables: Users and TransactionPaypalData
    ${
      email
        ? `by_email AS (
          SELECT DISTINCT "userId" FROM "Users" WHERE email LIKE $1 -- by Users.email
          UNION
          SELECT DISTINCT CP."userId" FROM "TransactionPaypalData" TPD -- by TransactionPaypalData.payerEmail
            JOIN "Transactions" T on T."transactionId" = TPD."transactionId"
            JOIN "Orders" O on O."orderId" = T."orderId"
            JOIN "CounterParties" CP on CP."counterPartyId" = O."counterPartyId"
            WHERE TPD."payerEmail" LIKE $1
      ),`
        : ""
    }
    -- Here we apply filters and pagination
    paginated_users AS (
      SELECT U."userId", U."createdAt", U."userId", U."email" FROM "Users" U
          ${email ? 'JOIN by_email MU ON U."userId" = MU."userId"' : ""}
          WHERE U."isUserUnlinked" = false
          ${userId ? `AND U."userId" = $2` : ""}
          ${
            createdAtTo && createdAtFrom
              ? `AND U."createdAt" BETWEEN $3 AND $4`
              : ""
          }

          GROUP BY U."userId", U."createdAt"
          ORDER BY U."createdAt" DESC
        OFFSET $5
        LIMIT $6
  )
  -- Since joins are expensive in previous query, we need to join them here for a smaller amount of users
    SELECT U.*, array_agg(TPD."payerEmail") as payer_emails FROM paginated_users U
      LEFT JOIN "CounterParties" CP on U."userId" = CP."userId"
      LEFT JOIN "Orders" ON CP."counterPartyId" = "Orders"."counterPartyId"
      LEFT JOIN "Transactions" T ON "Orders"."orderId" = T."orderId"
      LEFT JOIN "TransactionPaypalData" TPD ON T."transactionId" = TPD."transactionId"
      GROUP BY U."userId", U."createdAt", U."userId", U."email"
      ORDER BY U."createdAt" DESC
  `;

    // Default values are passed just to satisfy prisma params check
    // They are not used in query since we have a check for empty filters
    const likeEmailParam = `${email ? email + "%" : ""}`;
    const userIdParam = Number(userId || 0);
    const createdAtFromParam = new Date(createdAtFrom || 0);
    const createdAtToParam = new Date(createdAtTo || 0);
    const limitParam = Number(limit);
    const offsetParam = Number(offset);

    const result = await this.databaseService.$queryRawUnsafe<QueryUser[]>(
      query,
      likeEmailParam,
      userIdParam,
      createdAtFromParam,
      createdAtToParam,
      offsetParam,
      limitParam
    );

    return result.map(AdminRepository.toDomainModel);
  };

  public static toDomainModel(
    user: AdminUserDomainModel & { payer_emails: Array<string | null> }
  ): AdminUserDomainModel {
    const payerEmails = uniq(
      user.payer_emails.filter((email) => email !== null)
    ) as string[];

    return {
      createdAt: user.createdAt,
      userId: user.userId,
      email: user.email,
      payerEmails: payerEmails.length > 0 ? payerEmails.join("\n") : null,
    };
  }
}
