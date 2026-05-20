function test_target_import_roots(scope::JuliaProjectHarnessScope)
    Set(get(scope.targets, "test", String[]))
end
