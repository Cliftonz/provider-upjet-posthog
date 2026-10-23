import os
from datetime import datetime, timezone

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "posthog.settings")
django.setup()

from ee.models.license import License
from posthog.accessible_teams import AccessibleTeams
from posthog.models import PersonalAPIKey, User
from posthog.personal_api_key_minting import mint_personal_api_key

ADMIN_EMAIL = "admin@posthog-e2e.local"
MEMBER_EMAIL = "member@posthog-e2e.local"
PASSWORD = "posthog-e2e-password"

admin = User.objects.filter(email=ADMIN_EMAIL).first()
if admin:
    org = admin.organization
    team = admin.team
else:
    org, team, admin = User.objects.bootstrap("posthog-e2e", ADMIN_EMAIL, PASSWORD, "Admin")

member = User.objects.filter(email=MEMBER_EMAIL).first() or User.objects.create_and_join(
    org, MEMBER_EMAIL, PASSWORD, "Member"
)

License.objects.get_or_create(
    plan="enterprise",
    defaults={"key": "posthog-e2e", "valid_until": datetime(2099, 1, 1, tzinfo=timezone.utc)},
)

PersonalAPIKey.objects.filter(user=admin, label="posthog-e2e").delete()
minted = mint_personal_api_key(admin, label="posthog-e2e", scopes=["*"], teams=AccessibleTeams.all_for(admin))

print(f"POSTHOG_API_KEY={minted.value}")
print(f"POSTHOG_ORGANIZATION_ID={org.id}")
print(f"POSTHOG_PROJECT_ID={team.id}")
print(f"POSTHOG_TEST_USER_UUID={member.uuid}")
