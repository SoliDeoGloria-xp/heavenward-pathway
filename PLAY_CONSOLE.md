# Google Play Console: internal testing, step by step

## 1. Build the signed AAB (GitHub, works from a phone)

1. Repo → **Settings → Secrets and variables → Actions**. If you have not already, add `HPO_KEY_PASSPHRASE` (12+ characters). Keep it somewhere safe: it unlocks the upload key stored encrypted at `signing/upload.keystore.enc`.
2. **Actions → Android release (Play Console AAB) → Run workflow**.
   - `version_code`: must be higher than every earlier upload. This build is **3**. Add 1 each time.
   - `version_name`: `0.2.1`.
3. When it finishes, open **Releases**. A **draft** release holds `hpo-0.2.1-code3.aab`. Download it. (If the file name ends in `THROWAWAY-KEY`, the secret was missing: do not upload that one.)
4. The log line "manifest SDK levels" must show `targetSdkVersion 36`.

## 2. Play Console, first time only

1. **Create app**: name "Heavenward Pathway Online", language English (US), type **Game**, **Free**.
2. **Play App Signing**: accept (Google holds the app signing key; yours is the upload key).
3. **App content** (left menu, bottom). Suggested answers for this build:

| Form | Answer |
|---|---|
| Privacy policy | Required. A page stating: no account, no data collected or shared, save file stays on the device, birth year is used once to check age and is not stored |
| App access | All functionality available without special access |
| Ads | No ads |
| Content rating (IARC questionnaire) | Category: Game. Violence: **Yes, mild, fantasy** (cartoon creatures, no blood, defeated foes fade). Fear: mild. Sexuality, language, drugs, gambling: No. User interaction: **No** (no chat, no user content, no location sharing). In-app purchases: No. Religious references: note that the game is an allegory of a Christian book. Expect Everyone 10+ / PEGI 7 |
| Target audience | **13 and over** (13–15, 16–17, 18+). Not directed at children under 13; the age gate refuses under 13 |
| Data safety | Collects data: **No**. Shares data: **No**. (Offline; the save and settings are files on the device only. Vibration is the only permission.) |
| Government apps, financial features, health | No |
| News app | No |

4. **Store listing** (needed before review, not for internal testing): short description, full description, 512×512 icon, 1024×500 feature graphic, at least two landscape phone screenshots (the autotest screenshots work).

## 3. Internal testing release

1. **Testing → Internal testing → Testers**: create an email list, add yourself and testers, save. Copy the **opt-in link**.
2. **Create new release** → upload the `.aab` → release name `0.2.1 (3)` → notes, for example: "Acts I–II: Eden to the first Calling. Single-player, saves on device."
3. **Review release → Start rollout to Internal testing**.
4. Each tester opens the opt-in link on their phone, accepts, then installs from the Play Store. Updates arrive like any app.

## 4. Each later build

Raise `version_code` by 1, run the workflow, upload the new AAB as a new internal release.

## 5. Compliance notes

- **Target API**: the workflow builds against API 36 (min 24), which meets Play's current target-level rule for new apps.
- **Lord's Day Mode** blocks play on Sundays. Testers can turn on "Tester: play on the Lord's Day" in Settings while `G.DEV_UNLOCK` is true in `scripts/g.gd`. Set it to false before a public release.
- **Before production**: replace placeholder art, add audio, complete the store listing, and have the dialogue reviewed.
