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

#import "NGSQLiteConnection.h"

@implementation NGSQLiteConnection
{
	sqlite3 *conn;
}

- (void)dealloc
{
	if(conn) sqlite3_close(conn);
	[super dealloc];
}

- (NSString *)driverName
{
	return @"SQLite";
}

- (NSString *)quote:(id)object
{
	const char *src;
	char *buf;
	size_t len;
	NSString *dest;
	
	if((dest = [super quote:object]))
	{
		return dest;
	}
	src = [[object description] UTF8String];
	len = strlen(src);
	if((buf = sqlite3_mprintf("%Q", src)))
	{
		dest = [[NSString alloc] initWithUTF8String:buf];
		sqlite3_free(buf);
	}
	else
	{
		dest = nil;
	}
	return dest;
}

- (BOOL)connected
{
	if(conn)
	{
		return TRUE;
	}
	return false;
}

- (NSString *)now
{
	return [[NSString alloc] initWithString:@"CURRENT_TIMESTAMP"];
}

@end


@implementation NGSQLiteConnection (NGDBDriverMethods)

- (void) setError:(NSError **)result statement:(NSString *)statement rc:(int)rc
{
	NSString *reason;
	NGDBError *res;
	const char *err;
	
	if(result)
	{
		res = [NGDBError alloc];
		err = sqlite3_errmsg(conn);
		reason = [[NSString alloc] initWithCString:err encoding:NSUTF8StringEncoding];
		[res initWithDriver:@"SQLite" sqlState:nil code:rc reason:reason statement:statement];
		[reason release];
		*result = res;
	}
}

- (id) initDriverWithURL:(NSURL *)url options:(NSDictionary *)options status:(NSError **)status
{
	const char *host = NULL;
	int res;
	
	if([super initWithOptions:options status:status])
	{
		conn = NULL;
		multipleInsertLimit = 1;		
		if([url host])
		{
			host = [[url host] UTF8String];
			if(!host[0])
			{
				host = NULL;
			}
			if(strcasecmp(host, "localhost"))
			{
				if(status)
				{
					*status = [[NGDBError alloc] initWithDriver:@"SQLite" sqlState:nil code:-1 reason:@"Hostnames must be 'localhost' or not specified" statement:nil];
				}
				[self release];
				return nil;
			}
		}
		if(![url path])
		{
			if(status)
			{
				*status = [[NGDBError alloc] initWithDriver:@"SQLite" sqlState:nil code:-1 reason:@"sqlite:// URLs must include the full path to the database file" statement:nil];
			}
			[self release];
			return nil;
		}
		if(SQLITE_OK != (res = sqlite3_open([[url path] UTF8String], &conn)))
		{
			[self setError:status statement:nil rc:res];
			conn = NULL;
			[self release];
			return nil;
		}
	}
	return self;
}

- (void *)exec:(NSString *)query flags:(NGDBExecFlags)flags status:(NSError **)status
{
	const char *sql = [query UTF8String];
	sqlite3_stmt *stmt;
	int rc;
	
	if(execFlags & NGDBEF_DebugLog)
	{
		NSLog(@"SQLite: %@", query);
	}
	if(SQLITE_OK != (rc = sqlite3_prepare_v2(conn, sql, strlen(sql), &stmt, NULL)))
	{
		if(execFlags & NGDBEF_DebugLog)
		{
			NSLog(@"SQLite result=%d (%s)", rc, sqlite3_errmsg(conn));
		}		
		[self setError:status statement:query rc:rc];
		return NULL;
	}
	rc = sqlite3_step(stmt);
	if(rc == SQLITE_DONE)
	{
		sqlite3_finalize(stmt);
		stmt = NULL;
	}
	else if(rc != SQLITE_ROW)
	{
		sqlite3_finalize(stmt);
		[self setError:status statement:query rc:rc];
		return NULL;
	}
	if(status) *status = nil;
	return stmt;
}

- (void)freeResultSet:(void *)result
{
	sqlite3_stmt *stmt;
	
	if(result)
	{
		stmt = (sqlite3_stmt *) result;
		sqlite3_finalize(stmt);
	}
}

- (id)createResultSet:(void *)result status:(NSError **)status
{
	sqlite3_stmt *stmt;
	
	stmt = (sqlite3_stmt *) result;
	return [[NGSQLiteResultSet alloc] initWithSQLiteStatement:stmt connection:self status:status];
}

@end
