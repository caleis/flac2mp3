/*********************************************************************
 *                                                                   *
 *       UTF-8 TO UNICODE (UTF-16) CONVERTER                         *
 *                                                                   *
 *********************************************************************
 *                                                                   *
 *       Program name:     utf2uc                                    *
 *       Module name:      utf2uc.c                                  *
 *                                                                   *
 *                                                                   *
 *       Author:           Zoltan Fekete                             *
 *       Revised by:                                                 *
 *       Latest change:    03.02.2014                                *
 *                                                                   *
 *********************************************************************
 *                                                                   *
 *       Module description:                                         *
 *                                                                   *
 *       Reads an UTF-8 encoded textfile and converts it to Unicode  *
 *                                                                   *
 *       Version history:                                            *
 *       v1.0: initial version                                       *
 *                                                                   *
 *********************************************************************
 *       Copyright (C) Fekete Zoltan, 2001-2013                      *
 *********************************************************************/

/***** Standard header include files *****/

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <alloc.h>
#include <conio.h>
#include <string.h>

/***** Program specific header include files *****/

/***** Module macro definitions *****/

/* Definition of program version */

#define PGM_VER "1.0"

/* Definition of logical constants - if not defined already */

#ifndef FALSE
#define FALSE 0
#endif

#ifndef TRUE
#define TRUE 1
#endif

#ifndef MK_FP
#define MK_FP(seg,ofs) ((void far *)((unsigned long)((seg)<<16)|(ofs)))
#endif

/* Program constants */

#define UTF16_BOM 0xfeff

/***** Data type declarations *****/

typedef unsigned char byte;

typedef unsigned int word;

/***** Module function prototypes *****/

int main (int argc, char *argv []);
int ConvertUtf2uc (FILE *If, FILE *Of, int Nlc, int Be);
int WriteUc (FILE *Of, long UCh, int Be);
int WriteUcWord (FILE *Of, unsigned int UCh, int Be);
void PrintErr (long ByteCount, int CharValue, int State, char *ErrString);
void PrintUsage (void);

/***** Global variable declarations *****/

int Debug = 0;
FILE *DbgFile;

/***** Functions of module *****/

int main (int argc, char *argv [])
{
	int i, j;
   FILE *InFile, *OutFile;
   int LittleEndian = FALSE;
   int BigEndian = FALSE;
   int NewLineConv = FALSE;
   
   Debug = 0;

	fprintf (stderr,
            "utf2uc %s - Z Fekete (C) 2013 ", PGM_VER);

   fprintf (stderr, "\n\n");

   /* Process command line options: */

	for (i = 1; i < argc; i++)
		if (argv[i][0] == '-') {
			switch (tolower(argv[i][1])) {
         case 'n':
            NewLineConv = TRUE;
            break;
         case 'l':
            LittleEndian = TRUE;
            break;
         case 'b':
            BigEndian = TRUE;
            break;
         case 'd':
            Debug = atoi (&argv[i][2]);
            if ((Debug < 0) || (Debug > 2)) {
               fprintf (stderr, "Error: Valid debug levels are 0, 1, 2\n");
            }
            break;
         case 'h':
            PrintUsage ();
            break;
			default:
            fprintf(stderr, "Error: unknown option: '%s'\n", argv[i]);
				exit(1);
			}
		for (j = i; j < argc - 1; j++)	/* compress argument list */
			argv[j] = argv[j + 1];
		argc--;
		i--;
	}
	if ((argc < 2) || (argc > 3)) {
      PrintUsage ();
      exit (1);
   }
   if ((!LittleEndian) && (!BigEndian)) {
      LittleEndian = TRUE; /* setting default endianness */
   }
   if (LittleEndian && BigEndian) {
      fprintf (stderr, "Little and Big Endian settings are mutually exclusive, defaulting to LE\n");
      BigEndian = FALSE;
   }

   /* Start real work here */

   /* Open input file */

   if ((InFile = fopen (argv [1], "rt")) == NULL) {
      fprintf (stderr, "Error: cannot open input UTF-8 file\n");
      exit (1);
   }
   
   /* Open output file or stdout */
   
   if (argc == 3) {
      if ((OutFile = fopen (argv [2], "wb")) == NULL) {
         fprintf (stderr, "Error: cannot create output file\n");
         exit (1);
      }
   }
   else {
      if (Debug) {
         fprintf (stderr, "Output to stdout\n");
      }
      OutFile = stdout;
   }
   
   /* Open debug output file if debug level full defined */
   
   if (Debug == 2) {
      if ((DbgFile = fopen ("utf2uc.dbg", "wb")) == NULL) {
         fprintf (stderr, "Error: cannot create full debug output file\n");
         exit (1);
      }
   }

   /* Process input file */

   if (!ConvertUtf2uc (InFile, OutFile, NewLineConv, BigEndian)) {
      fprintf (stderr, "Input file read error\n");
      return (1);
   }
   
   if (fclose (OutFile)) {
      fprintf (stderr, "Error: Could not close output file\n");
   }
   if (Debug && (fclose (DbgFile))) {
      fprintf (stderr, "Error: Could not close debug output file\n");
   }
   return (0);
}


/* Convert UTF-8 files to Unicode (UTF-16)
    Parameters: If: pointer to input file
                Of: pointer to output file
                Nlc: new line conversion, i.e. converts all 0x0a to 0x0d, 0x0a pair (unix to dos conversion)
                Be: big endian encoding if TRUE, otherwise little endian.
    Returns:    TRUE if successful */

int ConvertUtf2uc (FILE *If, FILE *Of, int Nlc, int Be)
{
   int UtfCh;
   long UtfCtr = 0;
   long UcCh = 0;
   enum StateType {START, BOM0, BOM1, BOM2, START1, X2B1, X3B1, X3B2, X4B1, X4B2, X4B3, ENDF} State = START;
   int WriteOk;
   long LineNo = 1;
   
   if ((UtfCh = fgetc(If)) == EOF) {
      PrintErr (UtfCtr, UtfCh, State, "Empty input file");
      return (1);
   }
   WriteOk = WriteUc (Of, UTF16_BOM, Be);
   if (UtfCh == 0xef) {
      State = BOM0;
   }
   else {
      State = START1;
   }
   do {
   UtfCtr++;
   if (Debug == 2) {
      fprintf (DbgFile, "Line: %ld, UTF char counter: %ld, UTF-8 char: %x, State: %x\n", LineNo, UtfCtr, UtfCh, State);
   }
      switch (State) {
         case BOM0: /* only to read the next character */
            State = BOM1; 
            break;
         case BOM1: /* valid first BOM character 0xef received */
            if (UtfCh == 0xbb) {
               State = BOM2;
            }
            else {
               State = START1;
               PrintErr (UtfCtr, UtfCh, State, "Invalid UTF-8 BOM, 0xbb expected");
            }
            break;
         case BOM2: /* valid second BOM character 0xbb received */
            if (UtfCh == 0xbf) {
               State = START1;
            }
            else {
               State = START1;
               PrintErr (UtfCtr, UtfCh, State, "Invalid UTF-8 BOM, 0xbb expected");
            }
            break;
         case START1: /* next ASCII character or beginning of UTF-8 sequence */
            if(UtfCh == '\n') {
               LineNo++;
               if (Nlc) {
                  WriteOk = (WriteUc (Of, '\r', Be) && WriteUc (Of, '\n', Be));
                  break;
               }
            }
            if (UtfCh < 0x80) {
               WriteOk = WriteUc (Of, UtfCh & 0x7f, Be);
               break;
            }
            if ((UtfCh & 0xe0) == 0xc0) {
               UcCh = UtfCh & 0x1f;
               State = X2B1;
               break;
            }
            if ((UtfCh & 0xf0) == 0xe0) {
               UcCh = UtfCh & 0x0f;
               State = X3B1;
               break;
            }
            if ((UtfCh & 0xf8) == 0xf0) {
               UcCh = UtfCh & 0x07;
               State = X4B1;
               break;
            }
            break;
         case X2B1: /* processing second byte of 2 byte sequence */
            if ((UtfCh & 0xc0) == 0x80) {
               UcCh = (UcCh << 6) + (UtfCh & 0x3f);
               if ((UcCh >= 0x80) && (UcCh <= 0x7ff)) {
                  WriteOk = WriteUc (Of, (UcCh & 0x7ff), Be);
                  State = START1;
               }
               else {
                  State = START1;
                  PrintErr (UtfCtr, UtfCh, State, "UTF-8 2 byte sequence out of 0x80-0x7ff range");
               }
            }
            else {
               State = START1;
               PrintErr (UtfCtr, UtfCh, State, "Invalid UTF-8 2 byte sequence [byte 2]");
            }
            break;
         case X3B1: /* processing second byte of 3 byte sequence */
            if ((UtfCh & 0xc0) == 0x80) {
               UcCh = (UcCh << 6) + (UtfCh & 0x3f);
               State = X3B2;
            }
            else {
               State = START1;
               PrintErr (UtfCtr, UtfCh, State, "Invalid UTF-8 3 byte sequence [byte 2]");
            }
            break;
         case X3B2: /* processing third byte of 3 byte sequence */
            if ((UtfCh & 0xc0) == 0x80) {
               UcCh = (UcCh << 6) + (UtfCh & 0x3f);
               if ((UcCh >= 0x800) && (UcCh <= 0xffff)) {
                  if ((UcCh < 0xd800) && (UcCh > 0xdfff)) {
                     WriteOk = WriteUc (Of, (UcCh & 0xffff), Be);
                     State = START1;
                  }
                  else {
                     State = START1;
                     PrintErr (UtfCtr, UtfCh, State, "UTF-8 3 byte sequence coding invalid unicode range 0xd800-0xdfff [surrogate pair range]");
                  }
               }
               else {
                  State = START1;
                  PrintErr (UtfCtr, UtfCh, State, "UTF-8 3 byte sequence out of 0x800-0xffff range");
               }
            }
            else {
               State = START1;
               PrintErr (UtfCtr, UtfCh, State, "Invalid UTF-8 3 byte sequence [byte 3]");
            }
            break;
         case X4B1: /* processing second byte of 4 byte sequence */
            if ((UtfCh & 0xc0) == 0x80) {
               UcCh = (UcCh << 6) + (UtfCh & 0x3f);
               State = X4B2;
            }
            else {
               State = START1;
               PrintErr (UtfCtr, UtfCh, State, "Invalid UTF-8 4 byte sequence [byte 2]");
            }
            break;
         case X4B2: /* processing second byte of 3 byte sequence */
            if ((UtfCh & 0xc0) == 0x80) {
               UcCh = (UcCh << 6) + (UtfCh & 0x3f);
               State = X4B3;
            }
            else {
               State = START1;
               PrintErr (UtfCtr, UtfCh, State, "Invalid UTF-8 4 byte sequence [byte 3]");
            }
            break;
         case X4B3: /* processing third byte of 3 byte sequence */
            if ((UtfCh & 0xc0) == 0x80) {
               UcCh = (UcCh << 6) + (UtfCh & 0x3f);
               if ((UcCh >= 0x10000) && (UcCh <= 0x10ffff)) {
                  WriteOk = WriteUc (Of, (UcCh & 0x1fffff), Be);
                  State = START1;
               }
               else {
                  State = START1;
                  PrintErr (UtfCtr, UtfCh, State, "UTF-8 4 byte sequence out of 0x10000-0x10ffff range");
               }
            }
            else {
               State = START1;
               PrintErr (UtfCtr, UtfCh, State, "Invalid UTF-8 4 byte sequence [byte 4]");
            }
            break;
         case START:
         default:
            PrintErr (UtfCtr, UtfCh, State, "Input processor state machine error");
            State = START1;
            break;
      }
      UtfCh = fgetc(If);
   }
   while ((WriteOk) && (UtfCh != EOF));

   return (TRUE);
}

/* Writes the unicode character in UTF-16 format to output file
    For characters in range 0x00 - 0xffff character is written as 2 bytes, little endian
    For ranges above 0x10000 surrogating used as per UTF-16 definiton (4 bytes written)
    Parameters: Of: pointer to output file
                UCh: unicode character to be written in the range of 0x0 - 0x10ffff
                Be: BigEndian if TRUE, Little Endian otherwise
    Returns:    TRUE if successful */

int WriteUc (FILE *Of, long UCh, int Be)
{
   word UChh, UChl;

   if (Debug == 2) {
      fprintf (DbgFile, "  --> Unicode char: %lx ", UCh);
   }
   if (UCh < 0x10000) { /* write character as two bytes, unless in surrogate pair range */
      if ((UCh < 0xd800) || (UCh > 0xdfff)) {
         return (WriteUcWord (Of, (UCh & 0xffff), Be));
      }
      else {
         if (Debug) {
            fprintf (stderr, "Invalid UTF-8 value: %0lx (code in surrogate pair range)\n", UCh);
         }
         return (FALSE);
      }
   }
   else { /* if value is bigger than 16 bit range */
      if (UCh > 0x1f0000) { /*check if fits to unicode maximum range */
         if (Debug) {
            fprintf (stderr, "Too high Unicode character value: %0lx\n", UCh);
         }
         return (FALSE);
      }
      else { /* now surrogate pair to be written */
         UCh = UCh - 0x10000;
         UChh = 0xd800 + ((UCh >> 10) & 0x3ff);
         UChl = 0xdc00 + (UCh & 0x3ff);
         return (WriteUcWord(Of, UChh, Be) && WriteUcWord (Of, UChl, Be));
      }
   }
}

/* Writes one 16 bit word of Unicode character
    This function is used by the WriteUc function, 
    called once for normal, twice for surrogating characters
    Parameters: Of: pointer to output file
                UCh: unicode 16-bit character 
                Be: BigEndian if TRUE, Little Endian otherwise
    Returns:    TRUE if successful */

int WriteUcWord (FILE *Of, unsigned int UCh, int Be)
{
   if (Be) {
      if (Debug == 2) {
         fprintf (DbgFile, "--> %02x %02x\n", (UCh >> 8) & 0xff, UCh & 0xff);
      }
      return ((fputc ((UCh >> 8) & 0xff, Of) != EOF) && (fputc (UCh & 0xff, Of) != EOF));
   }
   else {
      if (Debug == 2) {
         fprintf (DbgFile, "--> %02x %02x\n", UCh & 0xff, (UCh >> 8) & 0xff);
      }
      return ((fputc (UCh & 0xff, Of) != EOF) && (fputc ((UCh >> 8) & 0xff, Of) != EOF));
   }
   return (TRUE);
}

/* Writes error message to stderr
    Parameters: ByteCount: byte counter value to be written in the message
                CharValue: current read UTF-8 character in hex
                State: state machine state variable (integer)
    Returns:    None */

void PrintErr (long ByteCount, int CharValue, int State, char *ErrString)
{
   fprintf (stderr, "*** Error in input file at byte %ld (value %02XH), processor state: %d: %s\n", ByteCount, CharValue & 0xff, State, ErrString);
}

/* Writes usage info to stderr
    Parameters: None
    Returns:    None */
    
void PrintUsage (void)
{
   fprintf (stderr, "Usage: utf2uc [options] utf8inputfile [unicodeoutputfile]\n");
   fprintf (stderr, "Options: -n converts unix newline (0x0a) to Windows CR-LF (0x0d, 0x0a)\n");
   fprintf (stderr, "         -l little endian UTF-16 encoding (default)\n");
   fprintf (stderr, "         -b big endian UTF-16 encoding\n");
   fprintf (stderr, "         -d<debuglevel> set debuglevel to 0 (no), 1 (limited), 2 (full, debug file)\n");
   fprintf (stderr, "         -h print usage infor (this text)\n");
   fprintf (stderr, "(default output file is stdout)\n");
}