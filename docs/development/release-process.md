# Create and Publish a Vulcan Release

## Prerequisites

- Ensure you have the necessary permissions to publish a release on the Vulcan repository.
- Familiarize yourself with the project's automated workflows.

## Create a new release
A draft release is automatically created every 14 days by the `create-draft-release.yml` workflow. The workflow also create a new tag by increasing the patch number of the previous release tag. The source code (zip & tar.gz) are also provided in the assets.


We will need to edit and review the draft release to add the release notes and adjust the version tag as needed.
### Review the Draft Release

1. Navigate to the main page of the Vulcan repository.
2. To the right of the list of files, click Releases.

<img width="848" alt="Screenshot 2023-03-28 at 3 27 02 PM" src="https://user-images.githubusercontent.com/46642178/228362808-0f86c58d-ae6e-4ab0-8c92-e6c2dc1728b2.png">

---

3. At the top of the page, click on the edit button on the latest draft release. If there's no draft release, create one by clicking on `Draft a new release`

<img width="1296" alt="Screenshot 2023-03-28 at 3 30 32 PM" src="https://user-images.githubusercontent.com/46642178/228362763-180f999b-2dc8-42f6-9f96-706cc8dde6c3.png">

---

4. Click on "Generate release notes" above the description field on the right to automatically generate release notes. The notes are generated based on the pull requests since the last release.
5. Manually review the release notes, making sure the changes are well-categorized and accurate.
6. Update the release version tag as needed, following the Semantic Versioning principle (major, minor, or patch). This should be based on the changes included in the release. In general, we will bump the patch number if changes only include dependencies update and bugs fixes. Bump the minor number if changes include new features, and the major number if changes include breaking changes that may break existing functionalities.

> You are encouraged to discuss major changes with the team before proceeding.

### Update Necessary Files

1. On your vulcan local environment:

      a. Checkout to the master branch `git checkout master` if not already on master.

      b. Ensure that your local master branch is up to date with `origin/master` by running `git pull`

 2. Update the necessary files:

      a. Update `VERSION` file with the new version number.
      
      b. Update `package.json` file: update the `version` field in this file with the new version number

      c. Update `README.md` file: update the `Latest Release` section by updating the version number to the new one

      <img width="1010" alt="Screenshot 2023-10-02 at 2 27 30 PM" src="https://github.com/mitre/vulcan/assets/46642178/70e7f830-490e-4a70-9881-36cca43918a4">
      

      d. Update the `CHANGELOG.md` file: This is done using the `github_changelog_generator` gem.

      - Install the gem locally: `gem install github_changelog_generator`

      - Edit the generator param file `.github_changelog_generator`: change the `future-release` param to the new release number.

      - Because GitHub only allows 50 unauthenticated requests per hour, it's better to run the generator script with authentication by using a token. If you do not already have a valid GitHub token, follow these [instructions](https://github.com/github-changelog-generator/github-changelog-generator#github-token) to generate one.

      - Run the following command to generate the new changelog: `github_changelog_generator --token <your-40-digit-token>`

 3. Commit and Push the Changes:

      ```bash
        git add .
        git commit -s -m "<The New Release Version Number (e.g. v2.1.4)>"
        git push
      ```

The draft release creation also trigger the test to run and the build and push of the docker image (`run-tests.yml` and `push-to-docker.yml` workflows).

However, additional verification needs to be done before publishing the release.

### Test and Deployment Verifications

#### Step 1: Verify the Test Suite and Docker Image Build

1. Go to the GitHub Actions tab in the Vulcan repository.
2. Check that the test suite and Docker image build workflows have run successfully after the draft release was created.
3. If the workflows have failed, review the logs, resolve the issues, and push the fixes to the repository.
4. If any fixes are pushed to the repository, make sure to regenerate the release notes and the assets to capture the update.
5. Pull the latest vulcan docker image `mitre/vulcan:latest` and run it with `docker compose`.

>> Ensure you have setup your docker secrets with ./setup-docker-secrets.sh. Also replace `build: .` with `image: mitre/vulcan:latest` in the `docker-compose.yml`. You can also build the image locally and test it. Just make sure to pull the most up to date code from the master branch.

6. If any issues, address them and repeat the testing process.

#### Step 2: Verify the Staging Deployment

1. The master branch is automatically deployed to the staging environment on heroku. Go to <https://github.com/mitre/vulcan/deployments/activity_log?environment=mitre-vulcan-staging>, and ensure that the deployment completed successfully.
2. Test the app thoroughly, ensuring that all features work as expected and there are no bugs.
3. Address any issues found in the staging deployment and repeat the testing process.

## Publish the Release

1. Once all checks have been completed and are successful, go back to the draft release, click on the edit button, then click on "Publish release" to publish the new Vulcan release.


With these steps completed, you have successfully published a new Vulcan release.
