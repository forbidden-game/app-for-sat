let counter = 0;

export interface UserInput {
  email?: string;
  password?: string;
  role?: "admin" | "student" | "parent";
  display_name?: string;
}

export const userFactory = {
  admin: (overrides: Partial<UserInput> = {}): UserInput => ({
    email: `admin_${Date.now()}_${counter++}@test.com`,
    password: "testpassword123",
    role: "admin",
    display_name: "Test Admin",
    ...overrides,
  }),

  student: (overrides: Partial<UserInput> = {}): UserInput => ({
    email: `student_${Date.now()}_${counter++}@test.com`,
    password: "testpassword123",
    role: "student",
    display_name: "Test Student",
    ...overrides,
  }),

  parent: (overrides: Partial<UserInput> = {}): UserInput => ({
    email: `parent_${Date.now()}_${counter++}@test.com`,
    password: "testpassword123",
    role: "parent",
    display_name: "Test Parent",
    ...overrides,
  }),
};

export function resetUserCounter(): void {
  counter = 0;
}
