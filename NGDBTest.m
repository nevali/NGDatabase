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

#include <stdio.h>

#include "NGDatabase.h"

int
main(int argc, char **argv)
{
	NGDBConnection *db;
	NGDBResultSet *rs;
	NSDictionary *row;
	NSError *err = nil;
	NSString *url;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if(argc < 2)
	{
		fprintf(stderr, "Usage: %s URL\n", argv[0]);
		fprintf(stderr, "  For example: mysql://yourname:password@localhost/dbname\n");
		return 1;
	}
	url = [[NSString alloc] initWithUTF8String:argv[1]];
	db = [[NGDBConnection alloc] initWithURLString:url options:nil status:&err];
	[url release];
	if(!db)
	{
		NSLog(@"Connection to %s failed: %@", argv[1], err);
		return 1;
	}

	NSLog(@"Creating a temporary table");
	if(![db executeSQL:@"CREATE TEMPORARY TABLE {ngdbtest} ("
		" [id] INT NOT NULL, "
		" [name] VARCHAR(64), "
		" PRIMARY KEY([id]) "
		 ")" withArray:nil status:&err])
	{
		NSLog(@"%@", err);
		[db release];
		return 1;
	}
	if(![db insertInto:@"ngdbtest" values:[NSArray arrayWithObjects:
		[NSDictionary dictionaryWithObjectsAndKeys:@"1", @"id", @"Mr John Smith", @"name",nil],
		[NSDictionary dictionaryWithObjectsAndKeys:@"5", @"id", @"Mr Fred Smith", @"name",nil],
		[NSDictionary dictionaryWithObjectsAndKeys:@"4", @"id", NGDBNull, @"name",nil],
		[NSDictionary dictionaryWithObjectsAndKeys:@"2", @"id", @"Mrs Harriet Jones", @"name",nil],
		[NSDictionary dictionaryWithObjectsAndKeys:@"3", @"id", @"Ms Sandra Shaw", @"name",nil],
		[NSDictionary dictionaryWithObjectsAndKeys:@"6", @"id", NGDBNull, @"name",nil],
		nil] status:&err])
	{
		NSLog(@"Error: %@", err);
		[db release];
		return 1;
	}	
	rs = [db query:@"SELECT * FROM {ngdbtest} WHERE [id] > ? AND [name] IS NOT NULL" status:&err,
		  @"1",
		  nil];
	if(rs)
	{
		NSLog(@"Result-set has %llu rows", [rs rowCount]);
		while((row = [rs nextAsDict]))
		{
			NSLog(@"Row: %@", row);
		}
		[rs release];
	}
	else
	{
		NSLog(@"No result-set returned: %@", err);
	}
	[db executeSQL:@"DROP TEMPORARY TABLE {ngdbtest}" withArray:nil status:NULL];
	
	[db release];
	
	[pool drain];
	
	return 0;
}