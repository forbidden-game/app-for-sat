let counter = 0;

export interface TagInput {
  name?: string;
  category?: string;
}

export const tagFactory = {
  create: (overrides: Partial<TagInput> = {}): TagInput => ({
    name: `tag_${Date.now()}_${counter++}`,
    category: "topic",
    ...overrides,
  }),

  topic: (name?: string): TagInput => ({
    name: name || `topic_${Date.now()}_${counter++}`,
    category: "topic",
  }),

  skill: (name?: string): TagInput => ({
    name: name || `skill_${Date.now()}_${counter++}`,
    category: "skill",
  }),

  difficulty: (name?: string): TagInput => ({
    name: name || `difficulty_${Date.now()}_${counter++}`,
    category: "difficulty",
  }),
};

export function resetTagCounter(): void {
  counter = 0;
}
