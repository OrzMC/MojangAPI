import Testing
import Foundation
@testable import MojangAPI

@Test
func decodeManifestSummaryFromFixtureFile() throws {
    guard let url = Bundle.module.url(forResource: "manifest", withExtension: "json") else {
        throw MojangAPIError.notFound
    }
    let data = try Data(contentsOf: url)
    let summary = try JSONDecoder().decode(ManifestSummary.self, from: data)
    #expect(!summary.latestRelease.isEmpty)
    #expect(!summary.latestSnapshot.isEmpty)
    #expect(!summary.versions.isEmpty)
    #expect(summary.versions.first?.type == .release || summary.versions.first?.type == .snapshot)
}

@Test
func decodeUserProfileFromFixtureFile() throws {
    guard let url = Bundle.module.url(forResource: "user_notch", withExtension: "json") else {
        throw MojangAPIError.notFound
    }
    let data = try Data(contentsOf: url)
    let profile = try JSONDecoder().decode(UserProfile.self, from: data)
    #expect(profile.name == "Notch")
    #expect(profile.id == "069a79f444e94726a5befca90e38aaf5")
}

@Test
func buildKindChannelNormalization() {
    #expect(BuildKind.release.channel == .release)
    #expect(BuildKind.snapshot.channel == .snapshot)
    // 非 release 一律归 snapshot
    #expect(BuildKind.oldBeta.channel == .snapshot)
    #expect(BuildKind.oldAlpha.channel == .snapshot)
}

@Test
func resolveChannelFromRealManifestFixture() throws {
    guard let url = Bundle.module.url(forResource: "manifest", withExtension: "json") else {
        throw MojangAPIError.notFound
    }
    let summary = try JSONDecoder().decode(ManifestSummary.self, from: Data(contentsOf: url))
    let release = try #require(summary.resolve(.release))
    #expect(release.id == "1.21.1")
    #expect(release.type == .release)
    let snapshot = try #require(summary.resolve(.snapshot))
    #expect(snapshot.id == "24w45a")
    #expect(snapshot.type == .snapshot)
}

@Test
func javaRequirementReadsMajorVersion() throws {
    let data = Data(#"{"javaVersion":{"component":"java-runtime-gamma","majorVersion":17}}"#.utf8)
    let requirement = try Mojang.javaRequirement(fromVersionJSON: data)
    #expect(requirement.majorVersion == 17)
    #expect(requirement.distribution == "temurin")
    #expect(requirement.runtimeKind == "jre")
}

@Test
func javaRequirementDefaultsToEight() throws {
    let requirement = try Mojang.javaRequirement(fromVersionJSON: Data("{}".utf8))
    #expect(requirement.majorVersion == JavaRequirement.defaultMajor)
}
