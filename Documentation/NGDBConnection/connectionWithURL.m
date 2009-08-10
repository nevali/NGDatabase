/* Establishing a database connection with connectionWithURL:options:status: */

NGDBConnection *db;
NSError *error = NULL;

if(!(db = [NGDBConnection connectionWithURL:[NSURL URLWithString:@"sqlite:///Users/me/example.db"] options:nil status:&error]))
{
	NSLog(@"Error establishing database connection: %@", error);
	[error release];
	return -1;
}
if([db rowForQuery:@"SELECT [id] FROM {users} WHERE [name] = ?" status:&error, @"johnsmith", nil])
{
	return 1;
}
if(error)
{
	NSLog(@"Error executing query: %@", error);
	[error release];
	return -1;
}
return 0;