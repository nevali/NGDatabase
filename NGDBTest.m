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
	NGDBStatement *st;
	NSDictionary *row;
	NSArray *rows;
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
	[db setDebugLog:TRUE];
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
	[db alias:@"TEST" forObject:@"ngdbtest"];
	
	if(![db insertInto:@"TEST" values:[NSArray arrayWithObjects:
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
	if(![db insertInto:@"TEST" values:[NSArray arrayWithObjects:
		[NSArray arrayWithObjects:@"id", @"name", nil],
		[NSArray arrayWithObjects:@"10",@"Superman", nil],
		[NSArray arrayWithObjects:@"11",@"Spider-Man", nil],
		[NSArray arrayWithObjects:@"12",NGDBNull, nil],
		[NSArray arrayWithObjects:@"13",@"Batman", nil],
		nil] status:&err])
	{
		NSLog(@"Error: %@", err);
		[db release];
		return 1;
	}	
	rs = [db query:@"SELECT * FROM {TEST} WHERE [id] > ? AND [name] IS NOT NULL" status:&err,
		  @"1",
		  nil];
	if(rs)
	{
		NSLog(@"Result-set has %llu rows", [rs rowCount]);
		while((row = [rs nextAsDict]))
		{
			NSLog(@"RS Row: %@", row);
		}
		[rs release];
	}
	else
	{
		NSLog(@"No result-set returned: %@", err);
	}	
	if(!(row = [db getRow:@"SELECT * FROM {TEST} WHERE [id] = ?" status:&err, @"3", nil]) && !err)
	{
		NSLog(@"Error: %@", err);
		[db release];
		return 1;
	}
	else if(!row)
	{
		NSLog(@"-getRow:status: produced no results");
	}
	else
	{
		NSLog(@"Single row: %@", row);
	}
	
	if(!(rows = [db getAll:@"SELECT * FROM {TEST} WHERE [id] BETWEEN ? AND ?" status:&err, @"3", @"6", nil]))
	{
		NSLog(@"Error: %@", err);
		[db release];
		return 1;
	}
	NSLog(@"Rows: %@", rows);
	[rows release];

	if(!(st = [db prepare:@"UPDATE {TEST} SET [name] = ? WHERE [id] = ?" status:&err]))
	{
		NSLog(@"Error during prepare: %@", err);
		[db release];
		return 1;
	}
	if(![st execute:&err, @"The Joker", @"13"])
	{
		NSLog(@"Error during prepared exec: %@", err);
		[st release];
		[db release];
		return 1;
	}
	if(![st execute:&err, @"Lex Luthor", @"10"])
	{
		NSLog(@"Error during prepared exec: %@", err);
		[st release];
		[db release];
		return 1;
	}		
	[st release];

	if(!(rows = [db getAll:@"SELECT * FROM {TEST} WHERE [id] BETWEEN ? AND ?" status:&err, @"10", @"13", nil]))
	{
		NSLog(@"Error: %@", err);
		[db release];
		return 1;
	}
	NSLog(@"Rows: %@", rows);
	[rows release];
	
		
	[db executeSQL:@"DROP TABLE {ngdbtest}" withArray:nil status:NULL];
	
	[db release];
	
	[pool drain];
	
	return 0;
}