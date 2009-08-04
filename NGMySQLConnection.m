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

#import "NGMySQLConnection.h"

@implementation NGMySQLConnection
{
	MYSQL *conn;
}

- (void)dealloc
{
	if(conn) mysql_close(conn);
	[super dealloc];
}

- (NSString *)driverName
{
	return @"MySQL";
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
	if(!(buf = (char *) malloc((len * 2) + 3)))
	{
		return nil;
	}
	buf[0] = '\'';
	len = mysql_real_escape_string(conn, &(buf[1]), src, len);
	buf[len + 1] = '\'';
	buf[len + 2] = 0;
	dest = [[NSString alloc] initWithBytes:buf length:(len + 2) encoding:NSUTF8StringEncoding];
	free(buf);
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
	return [[NSString alloc] initWithString:@"NOW()"];
}

@end


@implementation NGMySQLConnection (NGDBDriverMethods)

- (void) setError:(NSError **)result statement:(NSString *)statement
{
	NSString *state, *reason;
	NGDBError *res;
	
	if(result)
	{
		res = [NGDBError alloc];
		
		state = [[NSString alloc] initWithCString:mysql_sqlstate(conn) encoding:NSUTF8StringEncoding];
		reason = [[NSString alloc] initWithCString:mysql_error(conn) encoding:NSUTF8StringEncoding];
		[res initWithDriver:@"DBMySQL" sqlState:state code:mysql_errno(conn) reason:reason statement:statement];
		[state release];
		[reason release];
		*result = res;
	}
}

- (id) initDriverWithURL:(NSURL *)url options:(NSDictionary *)options status:(NSError **)status
{
	const char *host = NULL, *user = NULL, *pass = NULL, *db = NULL, *sock = NULL;
	const char *p;
	unsigned int port = 0;
	unsigned long flags;
	size_t c;
	NSArray *dbn;
	
	if([super initWithOptions:options status:status])
	{
		if(NULL == (conn = mysql_init(NULL)))
		{
			[self release];
			return nil;
		}
		flags = 0;
		if([url host])
		{
			host = [[url host] UTF8String];
			if(!host[0])
			{
				host = NULL;
			}
		}
		if([url user])
		{
			user = [[url user] UTF8String];
		}
		if([url password])
		{
			pass = [[url password] UTF8String];
		}
		if([url port])
		{
			port = [[url port] intValue];
		}
		if([url path])
		{
			dbn = [[url path] componentsSeparatedByString:@"/"];
			for(c = 0; c < [dbn count]; c++)
			{
				p = [[dbn objectAtIndex:c] UTF8String];
				if(p && p[0])
				{
					if(db)
					{
						NSLog(@"MySQL: warning: ignored additional non-empty path components following '%s'", db);
						break;
					}
					else
					{
						db = p;
					}
				}
			}
		}
		if(NULL == mysql_real_connect(conn, host, user, pass, db, port, sock, flags))
		{
			[self setError:status statement:nil];
			mysql_close(conn);
			conn = NULL;
			[self release];
			return nil;
		}
		if(0 != mysql_query(conn, "SET sql_mode='ANSI'") ||
			0 != mysql_query(conn, "SET NAMES 'utf8'") ||
			0 != mysql_query(conn, "SET storage_engine='InnoDB'") ||
			0 != mysql_query(conn, "SET time_zone='+00:00'"))
		{
			[self setError:status statement:nil];
			mysql_close(conn);
			conn = NULL;
			[self release];
			return nil;
		}
	}
	return self;
}

- (void *)exec:(NSString *)query status:(NSError **)status
{
	const char *sql = [query UTF8String];
	
	if(0 == mysql_real_query(conn, sql, strlen(sql)))
	{
		if(status)
		{
			*status = nil;
		}
		if(mysql_field_count(conn))
		{
			return mysql_store_result(conn);
		}
		return NULL;
	}
	[self setError:status statement:query];
	return NULL;
}

- (void)freeResultSet:(void *)result
{
	MYSQL_RES *res;
	
	if(result)
	{
		res = (MYSQL_RES *) result;
		mysql_free_result(res);
	}
}

- (id)createResultSet:(void *)result status:(NSError **)status
{
	MYSQL_RES *res;
	
	res = (MYSQL_RES *) result;
	return [[NGMySQLResultSet alloc] initWithMySQLResult:res connection:self status:status];
}

@end
