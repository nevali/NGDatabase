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

@implementation NGSQLiteResultSet
{
	id connection;
	sqlite3_stmt *result;
	NSArray *fieldNames;
	NSArray *fields;
	NSArray *rowArray;
	NSDictionary *rowDict;
	unsigned int cols;
	unsigned long long rows;
	unsigned long long rowIndex;
	BOOL eof;
	BOOL first;
	BOOL buffer;
	unsigned long *lengths;
}

- (id)initWithSQLiteStatement:(sqlite3_stmt *)stmt connection:(id)conn status:(NSError **)status
{
	NGDBExecFlags flags;
	int rc;
	
	if((self = [super init]))
	{
		connection = [conn retain];
		flags = [connection execFlags];
		buffer = TRUE;
		if(flags & NGDBEF_Unbuffered)
		{
			buffer = FALSE;
		}
		result = stmt;
		eof = FALSE;
		rowIndex = 0;
		first = TRUE;
		rows++;
		cols = sqlite3_column_count(stmt);
		if(buffer)
		{
			while(SQLITE_ROW == (rc = sqlite3_step(stmt)))
			{
				rows++;
			}
			if(rc == SQLITE_DONE)
			{
				sqlite3_reset(stmt);
				first = FALSE;
			}
			else
			{
				NSLog(@"SQLite error occurred - %d", rc);
				sqlite3_finalize(stmt);
				stmt = NULL;
				[self release];
				return nil;
			}
		}
	}
	return self;
}

- (void)dealloc
{
	if(result) sqlite3_finalize(result);
	if(rowDict) [rowDict release];
	if(rowArray) [rowArray release];
	if(fieldNames) [fieldNames release];
	[connection release];
	[super dealloc];
}


- (NSArray *)fieldNames
{
	NSMutableArray *f;
	NSString *s;
	unsigned int c;
	const char *fname;
	
	if(fields)
	{
		return fields;
	}
	if(!result)
	{
		return nil;
	}
	f = [[NSMutableArray alloc] initWithCapacity:cols];
	for(c = 0; c < cols; c++)
	{
		if(NULL == (fname = sqlite3_column_name(result, c)))
		{
			[f release];
			return nil;
		}
		s = [[NSString alloc] initWithUTF8String:fname];
		[f addObject:s];
		[s release];
	}
	fields = f;
	return fields;
}

- (unsigned int)colCount
{
	return cols;
}

- (unsigned long long)rowCount
{
	return rows;
}

- (unsigned long long)rowIndex
{
	return rowIndex;
}

- (BOOL)eof
{
	return eof;
}

- (BOOL)moveNext
{
	NSMutableArray *rowobj;
	NSString *s;
	unsigned int c;
	const unsigned char *colval;
	size_t collen;
	int rc;
	
	if(rowDict)
	{
		[rowDict release];
		rowDict = nil;
	}
	if(rowArray)
	{
		[rowArray release];
		rowArray = nil;
	}
	if(!first)
	{
		rc = sqlite3_step(result);
		if(rc == SQLITE_DONE)
		{
			eof = TRUE;
			lengths = NULL;
			return FALSE;
		}
		if(rc != SQLITE_ROW)
		{
			NSLog(@"SQLite error occurred - %d", rc);
			return FALSE;
		}
		eof = FALSE;
		rowIndex++;
	}
	first = FALSE;
	if(!(rowobj = [[NSMutableArray alloc] initWithCapacity:cols]))
	{
		return FALSE;
	}		
	for(c = 0; c < cols; c++)
	{
		if(SQLITE_NULL == sqlite3_column_type(result, c))
		{
			[rowobj addObject:NGDBNull];
		}
		else
		{
			colval = sqlite3_column_text(result, c);
			collen = sqlite3_column_bytes(result, c);			
			s = [[NSString alloc] initWithBytes:colval length:collen encoding:NSUTF8StringEncoding];
			[rowobj addObject:s];
			[s release];
		}
	}
	rowArray = rowobj;
	return TRUE;
}

- (NSArray *)rowAsArray
{
	return rowArray;
}

- (NSDictionary *)rowAsDict
{	
	NSMutableDictionary *rowobj;
	unsigned int c;
	
	if(!rowArray)
	{
		return nil;
	}
	if(rowDict)
	{
		return rowDict;
	}
	if(![self fieldNames])
	{
		return nil;
	}
	if(!(rowobj = [[NSMutableDictionary alloc] initWithCapacity:cols]))
	{
		return nil;
	}
	for(c = 0; c < cols; c++)
	{
		[rowobj setObject:[rowArray objectAtIndex:c] forKey:[fields objectAtIndex:c]];
	}
	rowDict = rowobj;
	return rowDict;
}

@end