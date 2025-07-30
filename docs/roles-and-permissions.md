# Roles and Permissions Guide

## User Roles

### 1. Member (Default Role)
Every user who signs up via GitHub OAuth starts as a member.

**Can do:**
- ✅ Create content (articles and links)
- ✅ Edit/delete their own content
- ✅ Post comments
- ✅ Edit/delete their own comments
- ✅ View all published content
- ❌ Cannot report content (must be trusted)
- ❌ Cannot access admin panel
- ❌ Cannot edit other users' content

### 2. Admin
Manually assigned role with full system access.

**Can do everything a member can, PLUS:**
- ✅ Access admin panel at `/admin`
- ✅ Edit/delete ANY content (not just their own)
- ✅ Edit/delete ANY comment
- ✅ Manage categories (create, edit, reorder, archive)
- ✅ Manage tags
- ✅ View and manage reported content
- ✅ Pin/unpin content to homepage
- ✅ View all users and their stats
- ✅ Archive/restore any record

## Trusted User Status (Not a Role!)

**Trusted user** is a calculated status based on contributions, NOT a role:

```ruby
def trusted?
  published_contents_count >= 3 && published_comments_count >= 10
end
```

### Requirements:
- 3+ published contents AND
- 10+ published comments

### Trusted User Permissions:
- ✅ Can report inappropriate content
- ✅ Shows "✓ Trusted User" badge on profile

## How Permissions Are Checked

### In Controllers:
```ruby
# Only owner or admin can edit
unless @content.user == current_user || current_user.admin?
  redirect_to root_path, alert: 'Not authorized'
end

# Only trusted users can report
unless current_user.trusted?
  redirect_to @content, alert: 'You must be a trusted user to report content.'
end
```

### In Views:
```erb
<!-- Show admin link -->
<% if current_user.admin? %>
  <%= link_to "Admin", "/admin" %>
<% end %>

<!-- Show report button -->
<% if current_user.trusted? %>
  <button>Report</button>
<% end %>
```

### In Routes:
```ruby
# Admin panel access
authenticate :user, ->(user) { user.admin? } do
  mount Avo::Engine, at: Avo.configuration.root_path
end
```

## Managing Roles

### Via Rails Console:
```bash
# Find user
user = User.find_by(username: 'newstler')

# Check current role
user.role        # => "member" or "admin"
user.member?     # => true/false
user.admin?      # => true/false

# Change role
user.admin!      # Make admin
user.member!     # Make regular member

# Or update directly
user.update!(role: :admin)
```

### Via Admin Panel:
1. Go to `/admin`
2. Click on "Users"
3. Edit any user
4. Change "Role" dropdown
5. Save

## Role Assignment Strategy

1. **All new users** → Start as members
2. **Trusted contributors** → Can become admins manually
3. **No automatic promotions** → Admin must manually promote users
4. **Admins are permanent** → No automatic demotion

## Security Notes

- Role is stored as integer in database (0 = member, 1 = admin)
- Default value is 0 (member) at database level
- Cannot be nil (null: false constraint)
- Only admins can change roles (via admin panel)
- No user can change their own role via the UI 