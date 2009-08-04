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
	[super dealloc];
}

#define VA_TO_NSARRAY(rest, array) { \
	int c; \
	va_list ap; \
	id *objs; \
	va_start(ap, rest); \
	for(c = 0; c < 64 && va_arg(ap, id); c++); \
	va_end(ap); \
	objs = (NSObject **) alloca((c + 1) * sizeof(id)); \
	va_start(ap, rest); \
	for(c = 0; c < 64 && (objs[c] = va_arg(ap, id)); c++); \
	va_end(ap); \
	array = [[NSArray alloc] initWithObjects:objs count:c]; \
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
	
	sql = [self intersperseQuery:query withArray:params];
	r = [self exec:sql status:&err];
	if(r)
	{
		[self freeResult:r];
		return TRUE;
	}
	else if(err)
	{
		if(status)
		{
			*status = err;
		}
		else
		{
			[err release];
		}
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
	void *result;
	id rs;
	
	sql = [self intersperseQuery:query withArray:params];
	result = [self exec:sql status:status];
	[sql release];
	if(result)
	{
		if((rs = [self createResultSet:result status:status]))
		{
			return rs;
		}
		[self freeResult:result];
		return nil;
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
 * Drivers may override this method.
 */
- (NSString *)quoteObject:(NSString *)objectName qualify:(BOOL)qualify
{
	NSString *db, *schema;
	
	if(qualify)
	{
		db = [self databaseName];
		schema = [self schemaName];
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

/** -intersperseQuery:withArray:
 *
 * Replaces unquoted instances of the '?' character with successive quoted
 * values taken from the specified array.
 *
 * Replaces unquoted table names contained within square brackets with
 * qualified quoted table names, substituting aliased table names as required.
 *
 * Drivers should not need to override this method.
 */
- (NSString *)intersperseQuery:(NSString *)query withArray:(NSArray *)array
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
		if(q && src[e] == q)
		{
			q = 0;
			e++;
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
		if(q)
		{
			e++;
			continue;
		}
		if(src[e] == '"' || src[e] == '\'' || src[e] == '`' || src[e] == '[')
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
		if(src[e] == '?')
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
				NSLog(@"Number of parameter placeholders exceeds number of supplied parameters");
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

/** -exec:status:
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

- (void *)exec:(NSString *)query status:(NSError **)status
{
	(void) query;
	
	if(status)
	{
		*status = [[NGDBError alloc] initWithDriver:nil sqlState:nil code:-1 reason:@"Cannot execute query: not connected to a database" statement:query];
	}
	return NULL;
}

@end
