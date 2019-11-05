use Test::More;
eval { require Test::CheckChanges };
if ($@) {
    plan skip_all => 'Test::CheckChanges required for testing the Changes file';
}
Test::CheckChanges::ok_changes();
