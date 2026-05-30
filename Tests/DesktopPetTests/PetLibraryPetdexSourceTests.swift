import Foundation
import DesktopPet

@MainActor
func runPetLibraryPetdexSourceTests() {
    let tests = PetLibraryPetdexSourceTests()
    tests.petdexSourceIsImported()
    tests.petdexSourceDisplayNameIsUserFacing()
    tests.petdexSourceCodableRoundTrips()
    tests.viewModelAllowsPetdexItemsToBeDeleted()
}

@MainActor
private struct PetLibraryPetdexSourceTests {
    func petdexSourceIsImported() {
        let item = makePetdexItem()
        expect(item.isImported, "Petdex library items should be treated as imported pets")
    }

    func petdexSourceDisplayNameIsUserFacing() {
        expect(PetSource.petdex.displayName == "Petdex", "Petdex source should display as Petdex")
    }

    func petdexSourceCodableRoundTrips() {
        do {
            let encoded = try JSONEncoder().encode(PetSource.petdex)
            let encodedString = String(data: encoded, encoding: .utf8)
            expect(encodedString == "\"petdex\"", "Petdex source should encode as petdex")

            let decoded = try JSONDecoder().decode(PetSource.self, from: encoded)
            expect(decoded == .petdex, "Petdex source should decode from petdex")
        } catch {
            fail("Petdex source should Codable round-trip: \(error)")
        }
    }

    func viewModelAllowsPetdexItemsToBeDeleted() {
        let item = makePetdexItem()
        let model = PetLibraryViewModel(
            store: PetdexSourceStubStore(items: [item]),
            selectedPetIdProvider: { "starter-pet" }
        )
        model.reload()

        var deletedIds: [String] = []
        model.onDeletePet = { deletedIds.append($0) }
        model.deletePet(id: item.id)

        expect(deletedIds == [item.id], "Petdex items should use the imported-pet delete path")
    }

    private func makePetdexItem() -> PetLibraryItem {
        PetLibraryItem(
            id: "my-cat-v3-large",
            displayName: "Beibei",
            source: .petdex,
            folderURL: URL(fileURLWithPath: "/tmp/Pets/my-cat-v3-large", isDirectory: true),
            previewURL: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}

private final class PetdexSourceStubStore: PetLibraryStoring, @unchecked Sendable {
    let builtInPetId: String = "starter-pet"
    let importedPetsDirectoryURL: URL = URL(fileURLWithPath: "/tmp/Pets", isDirectory: true)

    private let items: [PetLibraryItem]

    init(items: [PetLibraryItem]) {
        self.items = items
    }

    func listPets() throws -> [PetLibraryItem] {
        items
    }

    func loadDefinition(id: String) throws -> PetDefinition {
        throw PetLibraryError.petNotFound
    }

    func deleteImportedPet(id: String) throws {
        throw PetLibraryError.petNotFound
    }
}
