enum AddonResolutionClassification {
  standard,
  exact,
  branchCompatible,
  notVerified;

  bool get isVerifiedMatch {
    return this == AddonResolutionClassification.exact ||
        this == AddonResolutionClassification.branchCompatible;
  }

  bool get allowsInstallAction {
    return this != AddonResolutionClassification.notVerified;
  }
}
