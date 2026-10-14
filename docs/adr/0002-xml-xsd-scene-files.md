# XML scenes validated by XSD

Scene files will use versioned XML with a repository-owned XSD. The application validates files against the XSD when reading and before committing a save; saves are written to a temporary file and replace the target only after validation succeeds. Tests will compile the schema, accept valid scenes, reject invalid scenes, and verify save/load round trips. This makes the scene format an explicit, testable contract and prevents invalid saves from replacing good files.
