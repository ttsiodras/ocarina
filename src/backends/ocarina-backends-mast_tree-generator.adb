------------------------------------------------------------------------------
--                                                                          --
--                           OCARINA COMPONENTS                             --
--                                                                          --
--                  OCARINA.BACKENDS.MAST_TREE.GENERATOR                    --
--                                                                          --
--                                 B o d y                                  --
--                                                                          --
--            Copyright (C) 2010, European Space Agency (ESA).              --
--                                                                          --
-- Ocarina  is free software;  you  can  redistribute  it and/or  modify    --
-- it under terms of the GNU General Public License as published by the     --
-- Free Software Foundation; either version 2, or (at your option) any      --
-- later version. Ocarina is distributed  in  the  hope  that it will be    --
-- useful, but WITHOUT ANY WARRANTY;  without even the implied warranty of  --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General --
-- Public License for more details. You should have received  a copy of the --
-- GNU General Public License distributed with Ocarina; see file COPYING.   --
-- If not, write to the Free Software Foundation, 51 Franklin Street, Fifth --
-- Floor, Boston, MA 02111-1301, USA.                                       --
--                                                                          --
-- As a special exception,  if other files  instantiate  generics from this --
-- unit, or you link  this unit with other files  to produce an executable, --
-- this  unit  does not  by itself cause  the resulting  executable to be   --
-- covered  by the  GNU  General  Public  License. This exception does not  --
-- however invalidate  any other reasons why the executable file might be   --
-- covered by the GNU Public License.                                       --
--                                                                          --
--                 Ocarina is maintained by the Ocarina team                --
--                       (ocarina-users@listes.enst.fr)                     --
--                                                                          --
------------------------------------------------------------------------------

with Namet;  use Namet;
with Output; use Output;
--  with Utils;  use Utils;

with GNAT.OS_Lib; use GNAT.OS_Lib;

--  with Ocarina.Backends.Utils;
with Ocarina.Backends.MAST_Tree.Nodes;
with Ocarina.Backends.MAST_Tree.Nutils;
with Ocarina.Backends.MAST_Values;
with Ocarina.Backends.Messages;

package body Ocarina.Backends.MAST_Tree.Generator is

--   use Ocarina.Backends.Utils;
   use Ocarina.Backends.MAST_Tree.Nodes;
   use Ocarina.Backends.MAST_Tree.Nutils;
   use Ocarina.Backends.MAST_Values;
   use Ocarina.Backends.Messages;

   package MTN renames Ocarina.Backends.MAST_Tree.Nodes;

   procedure Generate_Defining_Identifier (N : Node_Id);
   procedure Generate_Literal (N : Node_Id);
   procedure Generate_MAST_File (N : Node_Id);
   procedure Generate_Processing_Resource (N : Node_Id);
   procedure Generate_Scheduling_Server (N : Node_Id);

   procedure Write (T : Token_Type);
   procedure Write_Line (T : Token_Type);

   function Get_File_Name (N : Node_Id) return Name_Id;
   --  Generate a file name from the package node given as parameter

   procedure Release_Output (Fd : File_Descriptor);
   --  Releases the output by closing the opened files

   function Set_Output (N : Node_Id) return File_Descriptor;
   --  Adjust the output depending on the command line options and
   --  return a file descriptor in order to be able to close it.

   -------------------
   -- Get_File_Name --
   -------------------

   function Get_File_Name (N : Node_Id) return Name_Id is
      Suffix : constant String := ".txt";
   begin
      --  The File name corresponding is the lowerd name of N

      Get_Name_String
        (Conventional_Base_Name
         (Name
          (Defining_Identifier
           (N))));

      --  Adding file suffix

      Add_Str_To_Name_Buffer (Suffix);

      return Name_Find;
   end Get_File_Name;

   ----------------
   -- Set_Output --
   ----------------

   function Set_Output (N : Node_Id) return File_Descriptor is
   begin
      if not Print_On_Stdout then
         declare
            File_Name : constant Name_Id
              := Get_File_Name (N);
            Fd : File_Descriptor;
         begin
            Get_Name_String (File_Name);

            --  Create a new file and overwrites existing file with
            --  the same name

            Fd := Create_File
               (Name_Buffer (1 .. Name_Len), Text);

            if Fd = Invalid_FD then
               raise Program_Error;
            end if;

            --  Setting the output

            Set_Output (Fd);
            return Fd;
         end;
      end if;

      return Invalid_FD;
   end Set_Output;

   --------------------
   -- Release_Output --
   --------------------

   procedure Release_Output (Fd : File_Descriptor) is
   begin
      if not Print_On_Stdout and then Fd /= Invalid_FD then
         Set_Standard_Output;
         Close (Fd);
      end if;
   end Release_Output;

   --------------
   -- Generate --
   --------------

   procedure Generate (N : Node_Id) is
   begin
      case Kind (N) is
         when K_MAST_File =>
            Generate_MAST_File (N);

         when K_Defining_Identifier =>
            Generate_Defining_Identifier (N);

         when K_Literal =>
            Generate_Literal (N);

         when K_Processing_Resource =>
            Generate_Processing_Resource (N);

         when K_Scheduling_Server =>
            Generate_Scheduling_Server (N);

         when others =>
            Display_Error ("other element in generator", Fatal => False);
            null;
      end case;
   end Generate;

   ----------------------------------
   -- Generate_Defining_Identifier --
   ----------------------------------

   procedure Generate_Defining_Identifier (N : Node_Id) is
   begin
      Write_Name (Name (N));
   end Generate_Defining_Identifier;

   -----------
   -- Write --
   -----------

   procedure Write (T : Token_Type) is
   begin
      Write_Name (Token_Image (T));
   end Write;

   ----------------
   -- Write_Line --
   ----------------

   procedure Write_Line (T : Token_Type) is
   begin
      Write (T);
      Write_Eol;
   end Write_Line;

   ----------------------
   -- Generate_Literal --
   ----------------------

   procedure Generate_Literal (N : Node_Id) is
   begin
      Write_Str (Image (Value (N)));
   end Generate_Literal;

   -----------------------
   -- Generate_MAST_File --
   -----------------------

   procedure Generate_MAST_File (N : Node_Id) is
      Fd : File_Descriptor;
      F : Node_Id;
   begin
      if No (N) then
         return;
      end if;
      Fd := Set_Output (N);
      if not Is_Empty (Declarations (N)) then
         F := First_Node (Declarations (N));
         while Present (F) loop
            Generate (F);
            F := Next_Node (F);
         end loop;
      end if;

      Release_Output (Fd);
   end Generate_MAST_File;

   ----------------------------------
   -- Generate_Processing_Resource --
   ----------------------------------

   procedure Generate_Processing_Resource (N : Node_Id) is
   begin
      Write_Line ("Processing_Resource (");
      Increment_Indentation;

      Write_Indentation (-1);
      if Regular_Processor (N) then
         Write_Line ("Type => Regular_Processor,");
      else
         Write_Line ("Type => Packet_Based_Network,");
      end if;

      Write_Indentation (-1);
      Write_Str ("Name => ");
      Write_Name (Node_Name (N));
      Write_Line (Tok_Colon);

      Write_Indentation (-1);
      Write (Tok_Avg_ISR_Switch);
      Write_Space;
      Write (Tok_Assign);
      if Avg_ISR_Switch (N) /= No_Node then
         Generate (Avg_ISR_Switch (N));
      else
         Write_Str ("0.00");
      end if;
      Write_Line (Tok_Colon);

      Write_Indentation (-1);
      Write (Tok_Best_ISR_Switch);
      Write_Space;
      Write (Tok_Assign);
      if Best_ISR_Switch (N) /= No_Node then
         Generate (Best_ISR_Switch (N));
      else
         Write_Str ("0.00");
      end if;
      Write_Line (Tok_Colon);

      Write_Indentation (-1);
      Write (Tok_Worst_ISR_Switch);
      Write_Space;
      Write (Tok_Assign);
      if Worst_ISR_Switch (N) /= No_Node then
         Generate (Worst_ISR_Switch (N));
      else
         Write_Str ("0.00");
      end if;
      Write_Line (Tok_Colon);

      Decrement_Indentation;
      Write_Indentation (-1);
      Write_Line (");");
   end Generate_Processing_Resource;

   --------------------------------
   -- Generate_Scheduling_Server --
   --------------------------------

   procedure Generate_Scheduling_Server (N : Node_Id) is
   begin
      Write_Line ("Scheduling_Server (");
      Increment_Indentation;

      Write_Indentation (-1);
      if Is_Regular (N) then
         Write_Line ("Type => Regular,");
      else
         Write_Str ("Type => ");
         Write_Name (Associated_Scheduler (N));
         Write_Line (Tok_Colon);
      end if;

      Write_Indentation (-1);
      Write_Str ("Name => ");
      Write_Name (Node_Name (N));
      Write_Line (Tok_Colon);

      if Parameters (N) /= No_Node then
         Write_Indentation (-1);
         Write (Tok_Parameters);
         Write_Space;
         Write (Tok_Assign);
         Write_Space;
         Write (Tok_Left_Paren);
         Generate (Parameters (N));
         Write (Tok_Right_Paren);
         Write_Line (Tok_Colon);
      end if;

      Write_Indentation (-1);
      Write (Tok_Server_Processing_Resource);
      Write_Space;
      Write (Tok_Assign);
      Write_Space;
      Write_Name (MTN.Server_Processing_Resource (N));
      Write_Line (");");
   end Generate_Scheduling_Server;

end Ocarina.Backends.MAST_Tree.Generator;
