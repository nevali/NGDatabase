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

@implementation NGMySQLResultSet
{
	id connection;
	MYSQL_RES *result;
	NSArray *fieldNames;
	NSArray *fields;
	NSArray *rowArray;
	NSDictionary *rowDict;
	unsigned int cols;
	unsigned long long rows;
	unsigned long long rowIndex;
	BOOL eof;
	BOOL fetched;
	MYSQL_ROW row;
	unsigned long *lengths;
}

- (id)initWithMySQLResult:(MYSQL_RES *)res connection:(id)conn status:(NSError **)status
{
	if((self = [super init]))
	{
		connection = [conn retain];
		result = res;
		eof = FALSE;
		cols = mysql_num_fields(result);
		rows = mysql_num_rows(result);
		rowIndex = 0;
		fetched = FALSE;
	}
	return self;
}

- (void)dealloc
{
	if(result) mysql_free_result(result);
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
	MYSQL_FIELD *fdef;
	
	if(fields)
	{
		return fields;
	}
	if(!result)
	{
		return nil;
	}
	fdef = mysql_fetch_fields(result);
	f = [[NSMutableArray alloc] initWithCapacity:cols];
	for(c = 0; c < cols; c++)
	{
		s = [[NSString alloc] initWithUTF8String:fdef[c].name];
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
	if((row = mysql_fetch_row(result)))
	{
		lengths = mysql_fetch_lengths(result);
		eof = FALSE;
		if(!(rowobj = [[NSMutableArray alloc] initWithCapacity:cols]))
		{
			return FALSE;
		}		
		for(c = 0; c < cols; c++)
		{
			if(row[c])
			{
				s = [[NSString alloc] initWithUTF8String:row[c]];
				[rowobj addObject:s];
				[s release];
			}
			else
			{
				[rowobj addObject:NGDBNull];
			}
		}
		rowArray = rowobj;
		if(fetched)
		{
			rowIndex++;
		}
		else
		{
			fetched = TRUE;
			rowIndex = 0;
		}
		return TRUE;
	}
	lengths = NULL;
	eof = TRUE;
	mysql_free_result(result);
	result = NULL;
	return FALSE;
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