# action-label-semaphore

This action manage a semaphore system using labels in a remote repository.

```yaml
    container:
      image: <..some-img..>
    steps:
      - name: Label Semaphore
        uses: hey-car/action-label-semaphore@<..some-version..>
        env:
          GITHUB_TOKEN: "<..some-token-with-access..>"
        with:
          pr-label: "<..some-label-name..>"
          argo-app-path: "<..some-file-path..>"
          argo-revision-path: "<..some-yaml-path..>"
          argo-repo: "<..some-repo-name..>"
          desired-revision: "<..some-tag..>"
```
