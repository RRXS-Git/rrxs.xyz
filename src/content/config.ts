import { defineCollection, z } from 'astro:content';

const blog = defineCollection({
  // Type-check frontmatter using a schema
  schema: z.object({
    title: z.string(),
    description: z.string(),
    // Transform string to Date object
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    heroImage: z.string().optional(),
    tags: z.array(z.string()).optional(),
    category: z.enum(['ai-learning', 'life', 'business', 'tech']).optional(),
    featured: z.boolean().optional(),
    draft: z.boolean().optional(),
  }),
});

const aiLearning = defineCollection({
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    heroImage: z.string().optional(),
    tags: z.array(z.string()).optional(),
    level: z.enum(['beginner', 'intermediate', 'advanced']).optional(),
    tools: z.array(z.string()).optional(),
  }),
});

const life = defineCollection({
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    heroImage: z.string().optional(),
    tags: z.array(z.string()).optional(),
    mood: z.enum(['inspiring', 'reflective', 'motivational', 'peaceful']).optional(),
  }),
});

const business = defineCollection({
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    heroImage: z.string().optional(),
    tags: z.array(z.string()).optional(),
    type: z.enum(['strategy', 'marketing', 'investment', 'startup']).optional(),
    industry: z.string().optional(),
  }),
});

export const collections = {
  blog,
  'ai-learning': aiLearning,
  life,
  business,
};
