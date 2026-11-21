# F-Droid merge request text for FITNS

Paste everything below the line into the MR description when you resubmit.
Title: `New app: FITNS`. Don't open it before **2027-01-24**, when the repo will be 3 months old.

---

## Abstract for new app inclusion

### Please introduce the functions and usage of your app in summary, and also attach some screenshots.

FITNS is an offline fitness tracker. Everything stays on the phone: no INTERNET permission, no accounts, no ads, no trackers.

- **Train:** log workouts (sets, reps, weight, effort), a rest timer that works with the screen locked, sensor rep counting for push-ups, jumps and squats, routines, programs and ready-made workouts per body part.
- **Move:** step counting with daily, weekly and monthly totals, plus a home-screen widget. Steps from bike rides are filtered out.
- **Eat:** calories and macros, a built-in food list, offline barcode scanning, and a calorie plan that adjusts to your weight trend.
- **Track:** weight, BMI, measurements, progress photos, water (it can be logged from the notification), sleep, streaks, records and badges.

Screenshots are in the upstream Fastlane folder: https://github.com/Parthmagdum/FITNS/tree/release/0.1.0/fastlane/metadata/android/en-US/images/phoneScreenshots

### Please elaborate why you wrote this app. Please highlight the unique functions it provides over other similar apps in F-Droid.

Most fitness apps need an account and send your health data to a server. I wanted one app that covers workouts, steps, food and body tracking and works fully offline. Compared with the fitness apps already on F-Droid, FITNS puts all of these in one place, counts reps with the phone's sensors, scans barcodes offline, and swaps exercises to match the equipment you have.

## Checklist

### Policy

* [x] The app complies with the [inclusion policy](https://f-droid.org/docs/Inclusion_Policy). _Pay special attention to Quality point 6._
* [x] The original app author has been notified (and does not oppose the inclusion). I am the author.
* [x] The upstream app source code repo contains the app metadata in a [Fastlane](https://gitlab.com/snippets/1895688) or [Triple-T](https://gitlab.com/snippets/1901490) folder structure. The summary and description must be included and images, icon, and changelog should also be provided for better user experience. The `en-US` locale must be included.

### Docs

* [x] Please read [the guide](https://gitlab.com/fdroid/fdroiddata/-/blob/master/CONTRIBUTING.md) first if this is your first contribution.
* [x] Please make sure your metadata follows the best practice in [our templates](https://gitlab.com/fdroid/fdroiddata/tree/master/templates).
* [x] Please read the [Build Metadata Reference](https://f-droid.org/docs/Build_Metadata_Reference/) and make sure your metadata is valid.
* [x] Please read the [Quick Start Guide](https://f-droid.org/en/docs/Submitting_to_F-Droid_Quick_Start_Guide/).

### Merge Request Setup

* [x] The title of this merge request should follow "New app: app name" format.
* [x] Please make sure your fdroiddata fork is public and your branch is not protected. See <https://docs.gitlab.com/user/project/repository/branches/protected/>.
* [x] Please read [our Git guide](https://gitlab.com/fdroid/wiki/-/wikis/Tips-for-fdroiddata-contributors/Git-Usage) if you don't know how to rebase your branch. Don't rebase your branch if there is no conflict.
* [x] All related [fdroiddata](https://gitlab.com/fdroid/fdroiddata/issues) and [RFP issues](https://gitlab.com/fdroid/rfp/issues) have been referenced in this merge request
* [x] Please only submit one app in one MR.

### Metadata

* [x] Metadata must be put in `metadata/<applicationId>.yml`.
* [x] Metadata must be a valid YAML file.
* [x] Metadata must use LF as line ending.
* [x] Don't add summary/description/changelog/images or anything that should be provided in upstream repo. Please check the Changes tab to make sure there is no other unrelated files added in the MR.
* [x] Releases are tagged and auto update is enabled unless there is a special reason.
* [x] There is an issue tracker and contact info of the author so that we can report bugs and contact the author.
* [x] An AuthorName must be added. It doesn't need to be the real name.
* [ ] External repos are added as git submodules instead of srclibs. You can update git submodules without opening an MR in this repo and the submodule is covered by our scanner. _Flutter is pulled in as the `flutter@3.47.8` srclib. I can switch to a Flutter submodule if you prefer._
* [ ] Enable [Reproducible Builds](https://f-droid.org/docs/Reproducible_Builds). We'll use your signature for improved security/reliability, also allowing users to switch between different channels. Do note that if you don't enable reproducible build then the apk will be signed with our key so you can't enable it later. If you can't enable this, please add the reasons here. _Not enabled yet. Please sign it with the F-Droid key._
* [ ] Setup abi split if the APK is large and the splitted ones can be much smaller. _Not set up yet. Happy to add it if the APK size calls for it._
* [x] Only the latest versions should be kept in the metadata before it's merged. If you update the metadata, please replace the old versions with the new ones.
* [x] Don't add any disabled versions in the metadata.
* [x] The `commit` field should be the full hash. Please don't use tag or branch in commit.

### Pipeline

* [ ] All pipelines should pass. _See the note below._
* [ ] All warnings and errors in the Reports tab should be fixed or explained.
* [x] F-Droid CI runners are under GitLab's FOSS program, so there's no need for you to pay for any CI time. If Gitlab starts asking for phone numbers or credit cards don't submit anything, just leave a note in the MR so we know we need to trigger the CI.

Note: the pipeline on my fork fails before any job starts (GitLab asks for account verification). Could a maintainer trigger the CI, please?
