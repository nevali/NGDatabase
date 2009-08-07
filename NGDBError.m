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

@implementation NGDBError
{
	NSString *desc;
}

- (id) initWithDriver:(NSString *)driverName sqlState:(NSString *)state code:(NSInteger) code reason:(NSString *)reason statement:(NSString *)statement
{
	NSMutableDictionary *dict;
	
	dict = [[NSMutableDictionary alloc] initWithCapacity:4];
	if(state)
	{
		[dict setObject:state forKey:@"sqlState"];
	}
	if(statement)
	{
		[dict setObject:statement forKey:@"statement"];
	}
	if(driverName)
	{
		[dict setObject:driverName forKey:@"driverName"];
	}
	if(reason)
	{
		[dict setObject:reason forKey:NSLocalizedDescriptionKey];
	}
	[super initWithDomain:NGDBErrorDomain code:code userInfo:dict];
	[dict release];
	return self;
}

- (NSString *) sqlState
{
	return [[self userInfo] objectForKey:@"sqlState"];
}

- (NSString *) statement
{
	return [[self userInfo] objectForKey:@"statement"];
}

- (NSString *) driverName
{
	return [[self userInfo] objectForKey:@"driverName"];
}

- (NSString *) description
{
	NSMutableArray *arr;
	NSString *t, *s;
	int d;
	
	if(desc)
	{
		return desc;
	}
	arr = [[NSMutableArray alloc] initWithCapacity:6];
	if((t = [self driverName]))
	{
		if((d = [self code]))
		{
			s = [[NSString alloc] initWithFormat:@"%@(%d): ", t, d];
		}
		else
		{
			s = [[NSString alloc] initWithFormat:@"%@: ", t];
		}			
		[arr addObject:s];
		[s release];
	}
	if((t = [self sqlState]))
	{
		s = [[NSString alloc] initWithFormat:@"SQLSTATE[%@]: ", t];
		[arr addObject:s];
		[s release];
	}
	if((t = [[self userInfo] objectForKey:NSLocalizedDescriptionKey]))
	{
		[arr addObject:t];
	}
	else
	{
		[arr addObject:@"Unknown error"];
	}
	if((t = [self statement]))
	{
		s = [[NSString alloc] initWithFormat:@"\nWhile executing: %@", t];
		[arr addObject:s];
		[s release];
	}
	desc = [arr componentsJoinedByString:@""];
	[arr release];
	return desc;
}

@end
