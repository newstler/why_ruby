# The Big "Why Ruby?" Update: New Domain, New Features, Fresh Design

A few weeks ago, something happened that made me rethink everything about WhyRuby.info.

The official Ruby website, ruby-lang.org, added a "Why Ruby?" section right on their home page. The quotes they featured were beautiful. Matz talking about programmer happiness. DHH on productivity. And I sat there thinking: wait, isn't that exactly what my site was supposed to do?

But here's the thing. Those are quotes from 2004, maybe 2008. Ruby has a whole new generation of developers who fell in love with it. Vladimir Dementiev (you might know him from Evil Martians) suggested something brilliant: why not let everyone share their own "why Ruby" moment?

So now you can. On your profile, write a couple of sentences about why you love Ruby. The AI takes your words and turns them into a proper testimonial with a heading, a subheading, and a bit of expansion on your idea. The carousel on the home page rotates through all of them. Each testimonial links back to your profile. Your words, your identity, featured on a site about why Ruby matters.

The AI part was tricky. I spent a lot of time making sure it doesn't sound like AI. No "tapestry of innovation" or "testament to excellence." Just your voice, slightly polished. If the system detects its own output sounds robotic, it regenerates. Up to three times.

## The Ruby Community gets its own home

The Community page became surprisingly popular. People were sorting by stars, by projects, filtering by company and location. Developers were discovering each other's open source work. The leaderboard became a thing.

It deserved its own domain: **rubycommunity.org**.

Same app underneath. Same database, same users. Sign in on one site, and you're signed in on the other. But now the community has its own identity. A site about Ruby developers themselves, where you can showcase your work.

When you visit rubycommunity.org, you land on the community grid. Clean URLs, just rubycommunity.org/yourusername. When you visit whyruby.info, you get the advocacy content, success stories, and that testimonial carousel.

The cross-domain authentication was an adventure. OAuth callbacks have to go to one domain, so I built a secure token system that syncs sessions between sites. One-time use tokens, 30-second expiration. Sign out on one, sign out on both.

## Everything else that changed

There was a long list of feature requests sitting in my notes. Most of them are done now.

**Hide repositories.** Click the eye icon on any repo in your profile, and it disappears from the public view. Useful for that experimental project you started at 2am.

**"Open to Work" badge.** Toggle it in your profile settings, and a red badge appears on your avatar. For developers looking for their next gig.

**Bio links.** Mention @someone in your bio, and it links to their GitHub. Drop a URL, and it becomes clickable.

**Ruby-shaped avatars.** Goodbye, circles. Your profile picture now sits inside a gem-shaped frame. The border turns red on hover.

**Infinite scroll.** The community page loads more members as you scroll. No more pagination buttons.

**Sticky navigation.** The menu on the home page follows you as you scroll down.

**GraphQL for GitHub data.** Behind the scenes, I rewrote the GitHub data fetching to use their GraphQL API with batching. Faster updates, fewer API calls.

**UUID v7 instead of ULID.** Technical, but it matters. All primary keys are now time-sortable UUIDs. Better for distributed systems.

**Fresh favicon and design touches.** The whole site feels tighter.

And bugs. Fixed maybe twenty of them. Broken filters on profile pages. Counter caches out of sync. Session issues on mobile. The kind of things you only notice when you use your own app every day.

## What's coming

Integration with RubyEvents.org to pull in conference talks and meetup data. Connecting repositories with blog posts that explain them. Importing companies' contributions to open source. More ways to make your profile tell your story.

## A personal note

I've spent nearly 20 years writing Ruby. Building products, integrating AI into workflows, helping teams ship faster. Right now, I'm looking for my next role.

If you know someone hiring, or if you're hiring, I'd love to hear from you. Drop me a line or share this with anyone who might be interested in a senior Ruby developer with a thing for AI and product thinking.

[Hire Yuri](https://blog.yurisidorov.com) | [WhyRuby.info](https://whyruby.info) | [RubyCommunity.org](https://rubycommunity.org)
