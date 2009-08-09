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

@implementation NGDBStatement
{
	NGDBConnection *connection;
	NSString *statement;
	NGDBExecFlags execFlags;
}

- (id)initWithStatement:(NSString *)stmt connection:(NGDBConnection *)conn status:(NSError **)status
{
	if((self = [super init]))
	{
		if(!(statement = [conn intersperseQuery:stmt substituteParams:NO paramsArray:nil addSuffix:nil status:status]))
		{
			[self release];
			return nil;
		}
		connection = [conn retain];
		execFlags = [conn execFlags];
	}
	return self;
}

- (void)dealloc
{
	if(connection)
	{
		[connection release];
	}
	if(statement)
	{
		[statement release];
	}
	[super dealloc];
}

- (NGDBConnection *)connection
{
	return connection;
}

- (NSString *)statement
{
	return statement;
}

- (BOOL)execute:(NSError **)status, ...
{
	NSMutableArray *array;
	BOOL r;
	
	VA_TO_NSARRAY(status, array);
	r = [self executeWithArray:array status:status];
	[array release];
	return r;
}

- (BOOL)executeWithArray:(NSArray *)params status:(NSError **)status
{
	void *res;
	NSError *err = NULL;
	
	if((res = [self exec:params flags:execFlags status:&err]))
	{
		[connection freeResult:res];
		return YES;
	}
	else if(!err)
	{
		return YES;
	}
	ASSIGN_ERROR(err, status);
	return NO;
}

- (id)query:(NSError **)status, ...
{
	NSMutableArray *array;
	id r;
	
	VA_TO_NSARRAY(status, array);
	r = [self queryWithArray:array status:status];
	[array release];
	return r;
}

- (id)queryWithArray:(NSArray *)params status:(NSError **)status
{
	void *res;
	id rs;
	NSError *err = NULL;
	
	if((res = [self exec:params flags:NGDBEF_None status:&err]))
	{
		if(!(rs = [connection createResultSet:res status:&err]))
		{
			ASSIGN_ERROR(err, status);
			return nil;
		}
		return rs;
	}
	else if(!err)
	{
		return nil;
	}
	ASSIGN_ERROR(err, status);
	return nil;
}	

@end

@implementation NGDBStatement (NGDBDriverMethods)

- (void *)exec:(NSArray *)params flags:(NGDBExecFlags)flags status:(NSError **)status
{
	NSString *query;
	void *result;
	
	if(!(query = [connection intersperseQuery:statement substituteParams:YES paramsArray:params addSuffix:nil status:status]))
	{
		return NULL;
	}
	result = [connection exec:query flags:flags status:status];
	[query release];
	return result;
}

@end