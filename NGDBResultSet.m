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

@implementation NGDBResultSet

- (NSDictionary *)nextAsDict
{
	NSDictionary *r;
	
	if([self moveNext] && (r = [self rowAsDict]))
	{
		return r;
	}
	return nil;
}
	
- (NSArray *)nextAsArray
{
	NSArray *r;
	
	if([self moveNext] && (r = [self rowAsArray]))
	{
		return r;
	}
	return nil;
}

- (unsigned int)colCount
{
	return 0;
}

- (unsigned long long)rowCount
{
	return 0;
}

- (unsigned long long)rowIndex
{
	return 0;
}

- (NSArray *)fieldNames
{
	return nil;
}

- (BOOL)moveNext
{
	return FALSE;
}

- (BOOL)eof
{
	return TRUE;
}

- (NSDictionary *)rowAsDict
{
	return nil;
}

- (NSArray *)rowAsArray
{
	return nil;
}

@end
