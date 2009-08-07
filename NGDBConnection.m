/*
 * Copyright (c) 2009 Mo McRoberts.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 * 3. The names of the author(s) of this software may not be used to endorse
 * or promote products derived from this software without specific prior
 * written permission.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, 
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY 
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * AUTHORS OF THIS SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "p_ngdatabase.h"	

@implementation NGDBConnection
{
@protected
	NSTimeZone *timeZone;
	NSMutableDictionary *aliases;
	NGDBExecFlags execFlags;
	int multipleInsertLimit;
}

/** +connectionWithURLString:options:status:
 *
 * Establish a database connection given a URL in string form and add it to the
 * autorelease pool.
 *
 * Drivers should not need to override this method, and doing so will have no
 * effect.
 */
+ (id) connectionWithURLString:(NSString *)urlString options:(NSDictionary *)options status:(NSError **)status
{
	id db;
	
	if((db = [[NGDBConnection alloc] initWithURLString:urlString options:options status:status]))
	{
		[db autorelease];
	}
	return db;
}

/** +connectionWithURL:options:status:
 *
 * Establish a database connection given an NSURL and add it to the autorelease
 * pool.
 *
 * Drivers should not need to override this method, and doing so will have no
 * effect.
 */
+ (id) connectionWithURL:(NSURL *)url options:(NSDictionary *)options status:(NSError **)status
{
	id db;
	
	if((db = [[NGDBConnection alloc] initWithURL:url options:(NSDictionary *)options status:status]))
	{
		[db autorelease];
	}
	return db;
}

/** -initWithURL:options:status:
 *
 * Establish a database connection given an NSURL.
 *
 * If an error occurs and status: is non-NULL, it will be modified to point to
 * the location of an NSError object describing the error.
 *
 * Drivers should not need to override this method, and doing so will have no
 * effect.
 */
- (id)initWithURL:(NSURL *)url options:(NSDictionary *)options status:(NSError **)status
{
	NGDatabase *dbm;
	Class impl = nil;
	id db;
	
	[self release];
	dbm = [NGDatabase sharedDatabaseManager];
	if((impl = [dbm driverForScheme:[url scheme]]))
	{
		if((db = [impl alloc]))
		{
			return [db initDriverWithURL:url options:options status:status];
		}
	}
	return nil;
}	

/** -initWithURLString:options:status:
 * 
 * Establish a database connection given a URL in string form.
 *
 * If an error occurs and status: is non-NULL, it will be modified to point to
 * the location of an NSError object describing the error.
 *
 * Drivers should not need to override this method, and doing so will have no
 * effect. 
 */
- (id)initWithURLString:(NSString *)urlString options:(NSDictionary *)options status:(NSError **)status
{
	NSURL *url;
	id conn;
	
	if(!(url = [[NSURL alloc] initWithString:urlString]))
	{
		NSLog(@"NGDBConnection: Failed to create NSURL from string %@", urlString);
		return nil;
	}
	conn = [self initWithURL:url options:options status:status];
	[NSURL release];
	return conn;
}

- (void)dealloc
{
	if(timeZone) [timeZone release];
	[aliases release];
	[super dealloc];
}

/** -executeSQL:status:, ...
 *
 * Execute a (possibly parametised) statement, returning TRUE if it executed
 * successfully, FALSE otherwise.
 *
 * executeSQL:status: will be marginally more efficient than query:status: if
 * the statement is known not to produce a result-set or the result-set is
 * not required.
 * 
 * If an error occurs and status: is non-NULL, it will be modified to point to
 * the location of an NSError object describing the error.
 *
 * Drivers should not need to override this method.
 */
- (BOOL) executeSQL:(NSString *)query status:(NSError **)status, ...
{
	NSArray *array;
	BOOL success;
	
	VA_TO_NSARRAY(status, array);
	success = [self executeSQL:query withArray:array status:status];
	[array release];
	return success;
}

/** -executeSQL:withArray:status:
 * 
 * Execute a parametised statement given an array of parameters and return TRUE
 * if the query executed successfully, FALSE otherwise.
 *
 * executeSQL:withArray:status: will be marginally more efficient than
 * query:withArray:status: if the statement is known not to produce a result-
 * set or the result-set is not required. 
 *
 * If an error occurs and status: is non-NULL, it will be modified to point to
 * the location of an NSError object describing the error.
 *
 * Drivers should not need to override this method. 
 */
- (BOOL) executeSQL:(NSString *)query withArray:(NSArray *)params status:(NSError **)status
{
	void *r;
	NSError *err = NULL;
	NSString *sql;
	
	if(!(sql = [self intersperseQuery:query substituteParams:TRUE paramsArray:params addSuffix:nil status:status]))
	{
		return FALSE;
	}
	r = [self exec:sql flags:execFlags status:&err];
	if(r)
	{
		[self freeResult:r];
		return TRUE;
	}
	else if(err)
	{
		ASSIGN_ERROR(err, status);
		return FALSE;
	}
	return TRUE;
}

/** -query:status:, ...
 *
 * Execute a (possibly parametised) query. If the query produced a result-set
 * (including if the result-set contains zero rows), then a NGDBResultSet
 * object will be returned. If the query did not produce a result-set (for
 * example, because it is an INSERT statement), then query:status: will
 * return nil.
 *
 * If the query is known in advance not to require a result-set, use
 * executeSQL:status: instead.
 *
 * If an error occurs, query:status: will return nil; if status: is non-NULL,
 * it will be modified to point to the location of an NSError object describing
 * the error.
 *
 * Drivers should not need to override this method. 
 */
- (id) query:(NSString *)query status:(NSError **)status, ...
{
	void *r;
	NSArray *array;
	
	VA_TO_NSARRAY(status, array);
	r = [self query:query withArray:array status:status];
	[array release];
	return r;
}

/** -query:withArray:status:
 *
 * Execute a (possibly parametised) query. If the query produced a result-set
 * (including if the result-set contains zero rows), then a NGDBResultSet
 * object will be returned. If the query did not produce a result-set (for
 * example, because it is an INSERT statement), then query:withArray:status:
 * will return nil.
 *
 * If the query is known in advance not to require a result-set, use
 * executeSQL:withArray:status: instead.
 *
 * If an error occurs, query:withArray:status: will return nil; if status: is
 * non-NULL, it will be modified to point to the location of an NSError object
 * describing the error.
 *
 * Drivers should not need to override this method.
 */
- (id) query:(NSString *)query withArray:(NSArray *)params status:(NSError **)status
{
	NSString *sql;
	NSError *err = NULL;
	void *result;
	id rs;
	
	if(!(sql = [self intersperseQuery:query substituteParams:TRUE paramsArray:params addSuffix:nil status:&err]))
	{
		ASSIGN_ERROR(err, status);
		return nil;
	}
	result = [self exec:sql flags:execFlags status:&err];
	[sql release];
	if(result)
	{
		if((rs = [self createResultSet:result status:&err]))
		{
			ASSIGN_ERROR(err, status);
			return rs;
		}
		[self freeResult:result];
		return nil;
	}
	else
	{
		ASSIGN_ERROR(err, status);
	}
	return nil;
}

/** -quote:
 *
 * Quote an object suitable for insertion into a query according to the
 * current connection parameters. The special values NGDBNull and NGDBDefault
 * return literal NULL and DEFAULT strings, respectively. [NSNull null] may be
 * supplied in place of NGDBNull, if desired.
 *
 * Any Objective C object supporting descriptionWithLocale: or description may
 * be quoted (as per NSString's formatting facilities).
 *
 * Drivers must override this method, but may call [super quote:value] in order
 * to make use of the special values. If the result of a call to
 * [super quote:value] is nil, a driver implementation should continue on to
 * quote the value themselves; otherwise the result can be returned to the
 * caller directly.
 */
- (NSString *)quote:(id)value
{
	if(value == NGDBNull || [value isKindOfClass:[NSNull class]])
	{
		return [[NSString alloc] initWithString:@"NULL"];
	}
	if(value == NGDBDefault)
	{
		return [[NSString alloc] initWithString:@"DEFAULT"];
	}
	return nil;
}

/** -quoteObject:qualify:
 *
 * Return the quoted form of an object name within the database suitable for
 * inclusion within a statement. Typical objects are databases, schemata,
 * tables, views, and so on. In most cases, the result will be the object name,
 * surrounded by double quotation marks.
 *
 * If the specified object name is an alias, the value of the qualify
 * argument is ignored, as resolved aliases are always as fully-qualified
 * as possible.
 *
 * Drivers should not need to override this method, but may if required.
 */
- (NSString *)quoteObject:(NSString *)objectName qualify:(BOOL)qualify
{
	NSString *s;
	
	if([objectName characterAtIndex:0] == '"')
	{
		return [objectName copy];
	}
	if((s = [self resolveAlias:objectName]))
	{
		return [s copy];
	}
	if(qualify)
	{
		return [self quoteObject:objectName inSchema:nil inDatabase:nil];
	}
	return [[NSString alloc] initWithFormat:@"\"%@\"", objectName];
}

/** -quoteObject:inSchema:inDatabase:
 *
 * Given an unqualified, unquoted object name and optional schema and
 * database names (defaulting to the current values if either are supplied
 * as nil), generate as fully-qualified quoted name as possible.
 *
 * Drivers should not need to override this method, but may if required.
 */
- (NSString *)quoteObject:(NSString *)objectName inSchema:(NSString *)schema inDatabase:(NSString *)db
{
	if(!db)
	{
		db = [self databaseName];
	}
	if(!schema)
	{
		schema = [self schemaName];
	}
	if(db && schema)
	{
		return [[NSString alloc] initWithFormat:@"\"%@\".\"%@\".\"%@\"", db, schema, objectName];
	}
	if(db)
	{
		return [[NSString alloc] initWithFormat:@"\"%@\".\"%@\"", db, objectName];
	}
	if(schema)
	{
		return [[NSString alloc] initWithFormat:@"\"%@\".\"%@\"", schema, objectName];
	}
	return [[NSString alloc] initWithFormat:@"\"%@\"", objectName]; 
}	

/** -now
 *
 * Return a properly-quoted string referring to the current date and time
 * suitable for insertion into a statement. If supported by the driver, this
 * will be a function call (or similar) such that the current time according
 * to the database server will be used. Otherwise, the current time will be
 * returned as a quoted string, according to the value of timeZone.
 *
 * Drivers should override this method where possible.
 */
- (NSString *)now
{
	NSDate *date;
	NSString *dest;
	
	date = [[NSDate alloc] init];
	dest = [date descriptionWithCalendarFormat:@"'%Y-%m-%d %H:%M:%S'" timeZone:timeZone locale:nil];
	[date release];
	return dest;
}

/** -connected
 *
 * Return TRUE if the client believes the connection is established to a
 * database server, FALSE otherwise. Ordinarily, this method will only return
 * FALSE if initWithURL:status: (or one of its variants) has not yet been
 * invoked.
 *
 * Drivers must override this method.
 */

- (BOOL) connected
{
	return FALSE;
}

/** -timeZone
 *
 * Return the NSTimeZone object associated with the connection.
 *
 * Drivers should not need to override this method.
 */
 
- (NSTimeZone *) timeZone
{
	return timeZone;
}

/** -setTimeZone:
 *
 * Set a new NSTimeZone object for the connection.
 *
 * Drivers should override this method if it is possible for the new timezone
 * to be communicated with the database server.
 */
- (void)setTimeZone:(NSTimeZone *)newTimeZone
{
	[timeZone release];
	timeZone = [newTimeZone retain];
}

/** -driverName:
 *
 * Return the name of the driver associated with this connection, or nil if
 * no connection has been established yet.
 *
 * Drivers must override this method.
 */
- (NSString *)driverName
{
	return nil;
}

/** -databaseName:
 *
 * Return the name of the database that this connection is associated with.
 *
 * Drivers must override this method.
 */
- (NSString *)databaseName
{
	return nil;
}

/** -schemaName:
 *
 * Return the name of the schema that this connection is associated with.
 *
 * Drivers should override this method if the database system supports
 * multiple schemata per database
 */
- (NSString *)schemaName
{
	return nil;
}

/** -insertInto:values:status:
 *
 * Insert one or more sets of values into the specified object (typically a
 * database table).
 *
 * values: may either be an NSDictionary (containing a single set of key-value
 * pairs) or an NSArray (containing one or more NSDictionary objects).
 *
 * Note that in the latter case (where an NSArray instance is passed to
 * insertInto:) the keys in each contained instance of NSDictionary must be
 * identical. Behaviour is undefined if this requirement is not met.
 *
 * If a dictionary key begins with an at-sign (@), the corresponding value
 * will be inserted into the query literally rather than quoted.
 *
 * There is a hard limit of 64 values per row.
 */

- (NSArray *)_quoteKeys:(NSArray *)keys quoted:(char *)quoted
{
	const char *cstr;
	size_t count, c;
	NSMutableArray *knames;
	NSString *s, *t, *k;
	
	count = [keys count];
	if(count > 64) return nil;
	knames = [[NSMutableArray alloc] initWithCapacity:count];
	for(c = 0; c < count; c++)
	{
		k = [keys objectAtIndex:c];
		cstr = [k UTF8String];
		if(cstr[0] == '@')
		{
			cstr++;
			quoted[c] = 0;
			t = [[NSString alloc] initWithUTF8String:cstr];
		}
		else
		{
			quoted[c] = 1;
			t = k;
		}
		s = [self quoteObject:t qualify:FALSE];
		if(t != k) [t release];
		[knames addObject:s];
		[s release];
	}
	return knames;
}

- (NSArray *)_quoteValues:(NSArray *)values quoted:(const char *)quoted
{
	size_t count, c;
	NSMutableArray *vlist;
	NSString *s;
	
	count = [values count];
	vlist = [[NSMutableArray alloc] initWithCapacity:count];
	for(c = 0; c < count; c++)
	{
		if(quoted[c])
		{
			s = [self quote:[values objectAtIndex:c]];
			[vlist addObject:s];
			[s release];
		}
		else
		{
			[vlist addObject:[values objectAtIndex:c]];
		}
	}
	return vlist;
}

#define EXEC_AND_FREE(s, res, r) \
	rp = [self exec:s flags:execFlags status:res]; \
	if(rp || !err) \
	{ \
		r = TRUE; \
		[self freeResult:rp]; \
	} \
	else \
	{ \
		r = FALSE; \
		if(status) \
		{ \
			*status = err; \
		} \
	}

- (BOOL)insertInto:(NSString *)target values:(id)values status:(NSError **)status
{
	char quoted[64];
	NSString *targ, *sql;
	NSArray *vlist, *klist;
	NSMutableArray *sqllist;
	id entry;
	int numrows;
	BOOL first, r;
	size_t n, count;
	void *rp;
	NSError *err = NULL;
	
	numrows = 0;
	targ = [self quoteObject:target qualify:TRUE];
	
	/* A simple set of key-value pairs, where the keys are field names */
	if([values isKindOfClass:[NSDictionary class]])
	{
		klist = [self _quoteKeys:[values allKeys] quoted:quoted];
		vlist = [self _quoteValues:[values allValues] quoted:quoted];
		sql = [[NSString alloc] initWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)",
			   targ, [klist componentsJoinedByString:@", "], [vlist componentsJoinedByString:@", "], nil];
		[klist release];
		[vlist release];
		[targ release];
		EXEC_AND_FREE(sql, &err, r);
		return r;
	}
	
	/* An array, either of NSArray objects, or of NSDictionary objects */
	if([values isKindOfClass:[NSArray class]])
	{
		count = [values count];
		if(!count)
		{
			[targ release];
			return TRUE;
		}
		sqllist = [[NSMutableArray alloc] initWithCapacity:count + 1];
		first = TRUE;
		klist = nil;
		for(n = 0; n < count; n++)
		{
			entry = [values objectAtIndex:n];
			/* ...it's an array of NSArrays */
			if([entry isKindOfClass:[NSArray class]])
			{
				if(first)
				{
					klist = [self _quoteKeys:entry quoted:quoted];
					first = FALSE;
					continue;
				}
				vlist = [self _quoteValues:entry quoted:quoted];
				if([sqllist count])
				{
					sql = [[NSString alloc] initWithFormat:@"(%@)", [vlist componentsJoinedByString:@", "], nil];
					[sqllist addObject:sql];
					[sql release];
					numrows++;
				}
				else
				{
					sql = [[NSString alloc] initWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", targ, [klist componentsJoinedByString:@", "], [vlist componentsJoinedByString:@", "], nil];
					[sqllist addObject:sql];
					[sql release];
					numrows++;
				}
				if(multipleInsertLimit && numrows >= multipleInsertLimit)
				{
					/* Execute the statement so far immediately */
					sql = [sqllist componentsJoinedByString:@", "];
					[sqllist release];
					EXEC_AND_FREE(sql, &err, r);
					if(!r)
					{
						[klist release];
						[vlist release];
						[targ release];
						return FALSE;
					}
					numrows = 0;
					sqllist = [[NSMutableArray alloc] initWithCapacity:count + 1];
				}
				continue;
			}
			
			/* It's neither an array of NSArrays, nor of NSDictionary objects */
			if(![entry isKindOfClass:[NSDictionary class]])
			{
				*status = [[NGDBError alloc] initWithDriver:[self driverName] sqlState:nil code:-1 reason:@"Cannot perform insertInto:values:status: where values: is an NSArray containing types other than NSDictionary and NSArray" statement:nil];
				[sqllist release];
				if(klist)
				{
					[klist release];
				}
				[targ release];
				return FALSE;
			}
			
			/* An array of NSDictionary objects */
			if(first)
			{
				klist = [self _quoteKeys:[entry allKeys] quoted:quoted];
				vlist = [self _quoteValues:[entry allValues] quoted:quoted];
				first = FALSE;
				sql = [[NSString alloc] initWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", targ, [klist componentsJoinedByString:@", "], [vlist componentsJoinedByString:@", "], nil];
				[sqllist addObject:sql];
				[sql release];
				numrows++;
			}
			else
			{
				vlist = [self _quoteValues:[entry allValues] quoted:quoted];
				sql = [[NSString alloc] initWithFormat:@"(%@)", [vlist componentsJoinedByString:@", "], nil];
				[sqllist addObject:sql];
				[sql release];
				numrows++;
			}
			[vlist release];
			if(multipleInsertLimit && numrows >= multipleInsertLimit)
			{
				/* Execute the statement so far immediately */
				sql = [sqllist componentsJoinedByString:@", "];
				[sqllist release];
				EXEC_AND_FREE(sql, &err, r);
				if(!r)
				{
					[klist release];
					[targ release];
					return FALSE;
				}
				numrows = 0;
				first = TRUE;
				klist = nil;
				sqllist = [[NSMutableArray alloc] initWithCapacity:count + 1];
			}
		}
		if(numrows)
		{
			[klist release];
			sql = [sqllist componentsJoinedByString:@", "];
		}
		[sqllist release];
	}
	else
	{
		if(status)
		{
			*status = [[NGDBError alloc] initWithDriver:[self driverName] sqlState:nil code:-1 reason:@"Cannot perform insertInto:values:status: where values: is neither an NSDictionary nor an NSArray" statement:nil];
		}
		return FALSE;
	}
	[targ release];
	if(numrows)
	{
		EXEC_AND_FREE(sql, &err, r);
		return r;
	}
	return TRUE;
}

/** -alias:forObject:
 *
 * Add an alias for the given table name in the current database and schema.
 *
 * By convention, aliases should be specified in all-caps.
 *
 * Drivers should not override this method.
 */
- (BOOL)alias:(NSString *)alias forObject:(NSString *)obj
{
	return [self alias:alias forObject:obj inSchema:nil inDatabase:nil];
}

/** -alias:forObject:inSchema:inDatabase:
 *
 * Add an alias for the given table name in the specified database and schema.
 * If schema and/or db are nil, the current schema and database names will be
 * used, as per -quoteObject:inSchema:inDatabase:
 *
 * By convention, aliases should be specified in all-caps.
 *
 * Drivers should not override this method.
 */
- (BOOL)alias:(NSString *)alias forObject:(NSString *)obj inSchema:(NSString *)schema inDatabase:(NSString *)db
{
	NSString *target;
	
	target = [self quoteObject:obj inSchema:schema inDatabase:db];
	[aliases setObject:target forKey:alias];
	[target release];
	return TRUE;
}

/** -resolveAlias:
 *
 * Return the fully-qualfied name corresponding to the specified alias.
 *
 * Returns nil if the given name has not been registered.
 */
- (NSString *)resolveAlias:(NSString *)alias
{
	return [aliases objectForKey:alias];
}

/** -getRow:status:, ...
 *
 * Perform the specified query and return the first row of the results as an
 * associative array (NSDictionary instance).
 * 
 * If an error occurs, or the query produced no results, nil will be returned.
 * In the former case, if status is non-NULL, it will be set to point to an
 * NSError instance describing the error condition.
 *
 * Drivers should not override this method, override -getRow:withArray:status:
 * instead.
 */

- (NSDictionary *)getRow:(NSString *)query status:(NSError **)status, ...
{
	NSMutableArray *params;
	NSDictionary *r;
	
	VA_TO_NSARRAY(status, params);
	r = [self getRow:query withArray:params status:status];
	[params release];
	return r;
}

/** -getRow:withArray:status:
 *
 * Perform the specified query and return the first row of the results as an
 * associative array (NSDictionary instance).
 *
 * Drivers should override this method to be more efficient (specifically: not
 * require the construction of an NGDBResultSet, and to modify the query to
 * add a "LIMIT"-style specifier).
 *
 * If an error occurs, or the query produced no results, nil will be returned.
 * In the former case, if status is non-NULL, it will be set to point to an
 * NSError instance describing the error condition.
 */
- (NSDictionary *)getRow:(NSString *)query withArray:(NSArray *)params status:(NSError **)status
{
	NSDictionary *dict;
	NGDBResultSet *rs;
	
	dict = nil;
	if((rs = [self query:query withArray:params status:status]))
	{
		if((dict = [rs nextAsDict]))
		{
			dict = [dict copy];
		}
		[rs release];
	}
	return dict;
}

/** -getAll:status:, ...
 *
 * Perform the specified query and return the all rows of the results as an
 * array (NSArray instance) of associative arrays (NSDictionary instances).
 * 
 * If an error occurs, or the query produced no results, nil will be returned.
 * In the former case, if status is non-NULL, it will be set to point to an
 * NSError instance describing the error condition.
 *
 * Drivers should not override this method, override -getRow:withArray:status:
 * instead.
 */

- (NSArray *)getAll:(NSString *)query status:(NSError **)status, ...
{
	NSMutableArray *params;
	NSArray *r;
	
	VA_TO_NSARRAY(status, params);
	r = [self getAll:query withArray:params status:status];
	[params release];
	return r;
}

/** -getAll:withArray:status:
 *
 * Perform the specified query and return the all rows of the results as an
 * array (NSArray instance) of associative arrays (NSDictionary instances).
 *
 * Drivers should override this method to be more efficient (specifically: not
 * require the construction of an intermediate NGDBResultSet).
 *
 * If an error occurs, nil will be returned and if status is non-NULL, it will
 * be set to point to an NSError instance describing the error condition.
 *
 * If the query was successful but the result-set was empty, an empty NSArray
 * will be returned.
 */
- (NSArray *)getAll:(NSString *)query withArray:(NSArray *)params status:(NSError **)status
{
	NSDictionary *dict;
	NSMutableArray *results;
	NGDBResultSet *rs;
	
	results = nil;
	if((rs = [self query:query withArray:params status:status]))
	{
		results = [[NSMutableArray alloc] initWithCapacity:[rs rowCount]];
		while((dict = [rs nextAsDict]))
		{
			[results addObject:dict];
		}
		[rs release];
	}
	return results;
}

/** - setUnbuffered:
 *
 * If TRUE, request that future queries be unbuffered if appropriate.
 * If FALSE, request that future queries should be buffered (the default).
 *
 * Typically, a driver's underlying implementation will buffer the results of
 * queries. This allows multiple queries to be interspersed with one another
 * in a single connection and also allows information, such as the total
 * number of rows in a result-set, to be returned before the end of the set
 * has been reached.
 *
 * In unbuffered mode, data is returned to the client by the database server
 * on a row-by-row basis, and generally only one query may be active at a time.
 * Attempting to execute a second query while an NGDBResultSet instance
 * resulting from an unbuffered query exists will cause an error.
 *
 * Note that the precise interpretation of this flag is implementation-defined,
 * and it may have no effect at all. Assuming that the above constraints apply
 * ensures that users of this framework will be portable between database
 * systems.
 *
 * Drivers should not override this method.
 */
- (void)setUnbuffered:(BOOL)flag
{
	if(flag)
	{
		execFlags |= NGDBEF_Unbuffered;
	}
	else
	{
		execFlags &= ~NGDBEF_Unbuffered;
	}
}

/** - isUnbuffered
 *
 * Return TRUE if the connection is in unbuffered mode, FALSE otherwise.
 *
 * Drivers should not override this method.
 *
 */
- (BOOL)isUnbuffered
{
	return (execFlags & NGDBEF_Unbuffered ? TRUE : FALSE);
}

/** - setUncached:
 *
 * If a database server has been configured to cache the results of identical
 * queries where the underlying objects have not caused the cache to become
 * invalidated, the default is to permit this to occur.
 *
 * If TRUE, request that future queries ignore any query-caching mechanisms.
 * If FALSE, request that future queries make use of available query caches
 * (the default).
 *
 * Note that the precise interpretation of this flag is implementation-defined,
 * and it may have no effect at all. Assuming that the above constraints apply
 * ensures that users of this framework will be portable between database
 * systems.
 *
 * Drivers should not override this method.
 */
- (void)setUncached:(BOOL)flag
{
	if(flag)
	{
		execFlags |= NGDBEF_Uncached;
	}
	else
	{
		execFlags &= ~NGDBEF_Uncached;
	}
}

/** - isUncached
 *
 * Return TRUE if the connection is in uncached mode, FALSE otherwise.
 *
 * Drivers should not override this method.
 *
 */
- (BOOL)isUncached
{
	return (execFlags & NGDBEF_Uncached ? TRUE : FALSE);
}

/** - prepare:status:
 *
 * Prepare a statement for later execution.
 *
 * A prepared statement is one which can be repeatedly executed, passing
 * alternative sets of parameters with each invocation. A database server
 * may make it possible to optimise this operation, where the query itself
 * is only parsed once and the parameters are substituted by the server at
 * invocation time.
 *
 * Upon success, an NGDBStatement instance will be returned representing
 * the statement.
 *
 * If an error occurs, nil will be returned and status:, if provided, will
 * be modified to point to an NSError instance describing the error condition.
 *
 * Note that aliases are resolved immediately upon calling this method
 * (rather than at statement invocation time), and that the returned
 * NGDBStatement instance will maintain the state of the unbuffered and
 * uncached flags and apply them consistently to any queries it executes.
 *
 * Drivers should override this method where they subclass NGDBStatement.
 */
- (id)prepare:(NSString *)stmt status:(NSError **)status
{
	return [[NGDBStatement alloc] initWithStatement:stmt connection:self status:status];
}

/** setDebugLog:
 *
 * Set the state of the debug-logging flag. Drivers may use this flag as an
 * indicator that application developer would like further feedback on executed
 * queries, result states, and so on.
 *
 * The precise meaning of this flag is implementation-defined, but a typical
 * driver's implementation would be to log executed queries using NSLog().
 *
 * Drivers should not override this method.
 */
- (void)setDebugLog:(BOOL)flag
{
	if(flag)
	{
		execFlags |= NGDBEF_DebugLog;
	}
	else
	{
		execFlags &= ~NGDBEF_DebugLog;
	}
}

@end

#pragma mark Driver methods

@implementation NGDBConnection (NGDBDriverMethods)

/** -initWithOptions:status:
 *
 * Placeholder constructor for use by driver implementations.
 *
 * Drivers should not directly override this method.
 */
- (id)initWithOptions:(NSDictionary *)options status:(NSError **)status
{
	NSString *tzname = nil;
	
	if((self = [super init]))
	{
		execFlags = NGDBEF_None;
		if(options)
		{
			if((tzname = [options objectForKey:@"timeZone"]))
			{
				timeZone = [[NSTimeZone alloc] initWithName:tzname];
			}
		}
		if(!tzname)
		{
			timeZone = [[NSTimeZone alloc] initWithName:@"UTC"];
		}
		aliases = [[NSMutableDictionary alloc] init];
	}
	return self;
}

/** -initDriverWithURL:status:
 *
 * Called internally by -initWithURL:status: in order to establish a
 * connection.
 *
 * Drivers must override this method.
 */
- (id)initDriverWithURL:(NSURL *)url options:(NSDictionary *)options status:(NSError **)status
{
	[self release];
	if(status)
	{
		*status = [[NGDBError alloc] initWithDriver:nil sqlState:nil code:-1 reason:@"Cannot initialise connection with no associated driver" statement:nil];
	}	
	return nil;
}

/** -intersperseQuery:substituteParams:paramsArray:addSuffix:status:
 *
 * Replaces unquoted instances of the '?' character with successive quoted
 * values taken from the specified array.
 *
 * Replaces unquoted table names contained within square brackets with
 * qualified quoted table names, substituting aliased table names as required.
 *
 * Drivers should not need to override this method.
 *
 * Nanosecond SQL syntax guide:
 *
 * SELECT [field] FROM {table} WHERE [field] = ? ORDER BY [field] ASC
 *
 * or, if you enjoy typing backslashes in C-style strings:
 *
 * SELECT "field" FROM {table} WHERE "field" = ? ORDER BY "field" ASC 
 *
 * Object names contained within square brackets will be replaced with quoted
 * object names (by -quoteObject:qualfied:, with qualfied:FALSE).
 *
 * Object names contained within curly braces are assumed to be table or view
 * names which should have alias matching performed upon them (where possible)
 * and fully-qualified (again, where possible).
 *
 * If substituteParams is TRUE, question marks denote parameters whose (raw)
 * values will be taken from the paramsArray: argument and quoted (via -quote:)
 * before insertion into the final result. If too few parameters are provided
 * for substitution, an error will occur and nil will be returned.
 *
 * If substituteParams is FALSE, question marks will be included literally
 * in the result and paramsArray: will be ignored.
 *
 * A typical result of interspersing the above statement would be:
 *
 * SELECT "field" FROM "mydb"."public"."sometable" WHERE "field" = 'widgets' ORDER BY "field" ASC
 *
 * Where "mydb" is the current database name (returned by -databaseName), 
 * "public" is the current schema name (returned by -schemaName), and the
 * withArray: argument specifies a single NSString parameter with the value
 * "widgets".
 */
- (NSString *)intersperseQuery:(NSString *)query substituteParams:(BOOL)substituteParams paramsArray:(NSArray *)array addSuffix:(NSString *)suffix status:(NSError **)status
{
	NSMutableArray *tarray;
	NSString *ret, *tmp;
	const char *src;
	size_t s, e, n, p, nobjs;
	int q;
	BOOL failed = FALSE, a;
	
	if(array)
	{
		nobjs = [array count];
	}
	else
	{
		nobjs = 0;
	}
	tarray = [[NSMutableArray alloc] init];
	src = [query UTF8String];
	s = e = 0;
	q = 0;
	n = 0;
	while(src[e])
	{
		if(q == '{' && src[e] == '}')
		{
			q = 0;
			if(!(tmp = [[NSString alloc] initWithBytes:&(src[s + 1]) length:(e - s - 1) encoding:NSUTF8StringEncoding]))
			{
				failed = TRUE;
				break;
			}
			if(!(ret = [self quoteObject:tmp qualify:TRUE]))
			{
				[tmp release];
				failed = TRUE;
				break;
			}
			[tmp release];
			[tarray addObject:ret];
			[ret release];
			e++;
			s = e;
			continue;
		}
		if(q == '[' && src[e] == ']')
		{
			q = 0;
			/* Detect array suffixes, which can be empty, or contain colon-
			 * separated lists of digits. We're flexible about the format, to
			 * allow the database server to deal with any errors. We can assume
			 * that something consisting entirely of digits and colons is not
			 * going to be a valid object name in its own right, whether or not
			 * it's a valid array specifier for the server.
			 */
			a = TRUE;
			for(p = s + 1; p < e; p++)
			{
				if(!isdigit(src[p]) && src[p] != ':')
				{
					a = FALSE;
					break;
				}
			}
			if(a)
			{
				/* Add the original string as a literal */
				if(!(tmp = [[NSString alloc] initWithBytes:&(src[s]) length:(e - s) encoding:NSUTF8StringEncoding]))
				{
					failed = TRUE;
					break;
				}
				[tarray addObject:tmp];
				[tmp release];
			}
			else
			{
				if(!(tmp = [[NSString alloc] initWithBytes:&(src[s + 1]) length:(e - s - 1) encoding:NSUTF8StringEncoding]))
				{
					failed = TRUE;
					break;
				}
				if(!(ret = [self quoteObject:tmp qualify:FALSE]))
				{
					[tmp release];
					failed = TRUE;
					break;
				}
				[tmp release];
				[tarray addObject:ret];
				[ret release];
			}
			e++;
			s = e;
			continue;
		}
		if(q && src[e] == q)
		{
			q = 0;
			e++;
			continue;
		}		
		if(q)
		{
			e++;
			continue;
		}
		if(src[e] == '"' || src[e] == '\'' || src[e] == '`' || src[e] == '[' || src[e] == '{')
		{
			if(e - s)
			{
				if(!(tmp = [[NSString alloc] initWithBytes:&(src[s]) length:(e - s) encoding:NSUTF8StringEncoding]))
				{
					failed = TRUE;
					break;
				}
				[tarray addObject:tmp];
				[tmp release];
			}
			s = e;
			q = src[e];
			e++;
			continue;
		}
		if(substituteParams && src[e] == '?')
		{
			if(e - s)
			{
				if(!(tmp = [[NSString alloc] initWithBytes:&(src[s]) length:(e - s) encoding:NSUTF8StringEncoding]))
				{
					failed = TRUE;
					break;
				}
				[tarray addObject:tmp];
				[tmp release];
			}
			if(!array || n >= nobjs)
			{
				if(status)
				{
					*status = [[NGDBError alloc] initWithDriver:[self driverName] sqlState:nil code:-2 reason:@"Number of parameter placeholders exceeds number of supplied parameters" statement:query];
				}
				failed = TRUE;
				break;
			}
			if(!(tmp = [self quote:[array objectAtIndex:n]]))
			{
				failed = TRUE;
				break;
			}
			[tarray addObject:tmp];
			[tmp release];
			n++;
			e++;
			s = e;
			continue;
		}
		e++;
	}
	if(failed)
	{
		[tarray release];
		return nil;
	}
	if(e - s)
	{
		if(!(tmp = [[NSString alloc] initWithBytes:&(src[s]) length:(e - s) encoding:NSUTF8StringEncoding]))
		{
			[tarray release];
			return nil;
		}
		[tarray addObject:tmp];
		[tmp release];
	}
	if(suffix)
	{
		[tarray addObject:suffix];
	}
	ret = [[tarray componentsJoinedByString:@""] copy];
	[tarray release];
	return ret;
}

/** -freeResult:
 *
 * Free the memory occupied by a driver-specific result-set data pointer.
 *
 * Drivers must override this method.
 */
- (void)freeResult:(void *)result
{
	(void) result;
}


/** -createResultSet:status:
 *
 * Create a NGDBResultSet object given a driver-specific result-set data
 * pointer, or return nil and set status to point to an NSError object upon
 * error.
 *
 * Drivers must override this method.
 */
- (id)createResultSet:(void *)result status:(NSError **)status
{
	(void) result;
	
	if(status)
	{
		*status = [[NGDBError alloc] initWithDriver:nil sqlState:nil code:-1 reason:@"Cannot create result-set: not connected to a database" statement:nil];
	}
	return nil;
}

/** -exec:flags:status:
 *
 * Execute a pre-processed statement, possibly returning a driver-specific
 * result-set data pointer.
 *
 * If an error occurs, exec:status: must return NULL and set status to point
 * to an NSError object describing the reason for the failure. exec:status:
 * may not be called with status:NULL.
 *
 * Drivers must override this method.
 */
- (void *)exec:(NSString *)query flags:(NGDBExecFlags)flags status:(NSError **)status
{
	(void) query;
	
	if(status)
	{
		*status = [[NGDBError alloc] initWithDriver:nil sqlState:nil code:-1 reason:@"Cannot execute query: not connected to a database" statement:query];
	}
	return NULL;
}

/** -execFlags
 *
 * Return the current set of execution flags associated with this connection.
 *
 * Drivers should not override this method.
 */
- (NGDBExecFlags) execFlags
{
	return execFlags;
}

@end
