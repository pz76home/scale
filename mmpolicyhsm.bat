# Used to process files from a Spectrum Scale MIGRATE policy

#!/usr/bin/perl -w
# @(#)38        1.4  src/avs/fs/mmfs/samples/ilm/mmpolicyExec-hsm.sample, mmfs, avs_rttn423, rttn4231713c 10/7/09 18:14:37
#
#
# This is a sample GPFS mmapplypolicy EXEC script for external pools.
# The script demonstrates how commands to an external storage manager,
# such as the Tivoli Storage Manager for Space Management (HSM) client
# can be invoked by the GPFS mmapplypolicy to migrate data to and from
# the external storage manager.
#
# To utilize the EXEC script, the script can be modified as necessary,
# then installed on all nodes in the home cluster or on all nodes that
# have installed the external storage manager. The script may be
# installed in an arbitrary directory at each node, such as
#       /var/mmfs/etc/mmpolicyExec-hsm.sample
# You must also ensure that the script is executable on each node
#      (chmod +x /var/mmfs/etc/mmpolicyExec-hsm.sample)
#
# The script is invoked by mmapplypolicy or one of its helper processes.
# The mmapplypolicy program must be invoked on a node that has the script
# installed and the file system mounted. The mmapplypolicy command can be run
# in parallel by specifying a node list on the command line using the -N option.
# The script should be installed on each node in the list, but if it is not
# the mmapplypolicy program will automatically drop the node from the list.
#
# The policy file provided to mmapplypolicy must contain the definition
# for the external pool and rules to migrate files to and/or from the external
# pool. For example:
#
# RULE EXTERNAL POOL 'hsm' EXEC '/var/mmfs/etc/mmpolicyExec-hsm.sample' OPTS '-v'
#
# RULE 'MoveOffline' MIGRATE
#           FROM POOL 'bronze'
#                     THRESHOLD(90,80)
#                     WEIGHT(KB_ALLOCATED)
#           TO POOL 'hsm'
#           WHERE KB_ALLOCATED > 1024
#             AND (DAYS(CURRENT_TIMESTAMP) - DAYS(ACCESS_TIME)) > 30
#
# The first rule defines an external pool named 'hsm' and defines the
# command interface script as '/var/mmfs/etc/mmpolicyExec-hsm.sample'.
# The optional OPTS field defines an options string '-v' to be passed
# to the EXEC. The OPTS string is not interpreted by mmapplypolicy.
#
# The second rule selects files to be migrated from the on-line 'bronze' pool
# to the external 'hsm' pool. The rules selects files that have more than 1MB
# of data on-line and have not been accessed in 30 days. The files are only
# moved if the 'bronze' pool is more than 90% full. The files are migrated
# in order by their size - largest files first - until the 'bronze' pool's
# utilization is reduced to 80% full.
#
# The mmapplypolicy program will determine the files for migration and invoke
# the EXEC script '/var/mmfs/etc/mmpolicyExec-hsm.sample' at each specified
# node. The arguments to the EXEC script are the command, the filelist file
# and any optional arguments from the OPTS field.
#
# The commands to the script are:
#
# MIGRATE filelist       -- Migrate files to external storage
#                           and reclaim the on-line space allocated to the file
# PREMIGRATE filelist    -- Premigrate files to external storage
#                           but do not reclaim the on-line space
# RECALL filelist        -- Recall files from external storage to the on-line
# PURGE filelist         -- Purge/Delete files in the external storage
# LIST filelist          -- List provides arbitrary lists of files
#                           with no semantics on the operation
# TEST /pathToFileSystem -- Test for the script presence and operation
#                           Return zero for success
#                           Return non-zero to drop from node from worker list
#
# For the example policy rule above, the EXEC script would be invoked like:
#
#   /var/mmfs/etc/mmpolicyExec-hsm.sample MIGRATE /tmp/filelist -v
#
#
# The filelist file contains the list of files to be operated on. The file
# contains one selected file per line as follows:
#
#   InodeNumber GenNum SnapId [Optional SHOW Args] -- /fullPathToFile
#
# Note that the InodeNumber and SnapId are 64-bit integers, the GenNum is 32.
# File names might not be in ASCII. File names that contain the '\n' character
# are translated to contain the "\n" string.
#
# Output from this script, whether on stdout or stderr, is captured by
# mmapplypolicy and included with its stdout. The caller to mmapplypolicy
# can scan the resulting output for errors or additional processing.
#
# The script should return 0 to indicate success. A non-zero return code
# will exclude this node from further processing.
#
#
##############################################################################


# Initialize global vars
$Verbose = 0;
$VerboseOption = "";


# Set binding to HSM commands
$MigrateCommand = "/usr/bin/dsmmigrate";
$PremigrateCommand = "/usr/bin/dsmmigrate";
$RecallCommand = "/usr/bin/dsmrecall";

# Set command formats:
#    Command Options Files
$MigrateFormat = "%s %s -filelist=%s";
$PremigrateFormat = "%s %s -premigrate -filelist=%s";
$RecallFormat = "%s %s -filelist=%s";

# Set command options
$VerboseCommandOption = "-detail";

# Set output filter to show only the errors, not the expected command output
#   Print command output lines that start with ANS or ANR
$FilterOutput = "^AN[S|R]";



# Validate arg count -- error exit if less than 2 args
die "Usage: $0 Command FilelistFile [Opts]\n" if ($#ARGV < 1);


# First argument is the command to the script
$command = shift @ARGV;

# Second argument is usually the file contain the list
# Except for the TEST command, where it is the path to the filesystem
$filelist = shift @ARGV;

# Process any options
foreach $opt (@ARGV) {
    if ($opt eq "-v") {
        $Verbose = 1;
        $VerboseOption = $VerboseCommandOption;
    }
}

print "$0 $command $filelist @ARGV\n" if ($Verbose > 0);


# Validate command
if (($command ne "MIGRATE") &&
    ($command ne "PREMIGRATE") &&
    ($command ne "RECALL") &&
    ($command ne "PURGE") &&
    ($command ne "LIST") &&
    ($command ne "TEST")) {
    print "$0: Invalid command: $command\n" if ($Verbose > 0);
    exit 1;
}

# Handle TEST command by verifying that HSM commands are installed
if ($command eq "TEST") {

    # Verify HSM commands are installed on this node
    print "$command -x $MigrateCommand\n" if ($Verbose > 0);
    exit 1 if !(-x $MigrateCommand);

    if ($PremigrateCommand ne $MigrateCommand) {
        print "$command -x $PremigrateCommand\n" if ($Verbose > 0);
        exit 1 if !(-x $PremigrateCommand);
    }

    if (($RecallCommand ne $MigrateCommand) &&
        ($RecallCommand ne $PremigrateCommand)) {
        print "$command -x $RecallCommand\n" if ($Verbose > 0);
        exit 1 if !(-x $RecallCommand);
    }
    print "$0: $command Ok\n" if ($Verbose > 0);
    exit 0;
}


# All other commands use the filelist file

# Convert gpfs filelist to an HSM filelist
# GPFS: inode gennum snapid -- /fullPathToFile
# HSM:  "/fullPathToFile"

$hsmfilelist = $filelist . ".hsm";

open(GL, "<", $filelist)
    or die "$0: Can't open $filelist: $!\n";
open(FL, ">", $hsmfilelist)
    or die "$0: Can't open $hsmfilelist for writing: $!\n";
foreach $file (<GL>) {
    chomp($file);
    $file =~ s/.*? -- //; # non greedy matchup in case " -- " appears in filename

    $file =~ s/\\\\/\\/g; # unescape backslashes (\\ and \n already escaped by GPFS policy)

    # TSM/HSM does NOT support names containing \n - so leave that alone.
    # Fix this code when TSM/HSM -filelist facility is fixed to support all valid Unix pathnames!

    # HSM does not support file names containing a mix of " and '.
    # add double quotes if the file name contains a single quote
    # add single quotes otherwise
    if ($file =~ /\'/) {
        print FL "\"" . $file . "\"\n";
    }
    else {
        print FL "\'" . $file . "\'\n";
    }

}
close FL;
close GL;

# Handle commands that are usually outside of HSM
if ($command eq "PURGE") {

    # Simply remove the file from the on-line file system
    # If the file is managed, the HSM will receive a dmapi destroy event
    open(FL, "<", $hsmfilelist)
        or die "$0: Can't open $hsmfilelist: $!\n";

    foreach $file (<FL>) {
        chomp($file);
        $syscmd = "rm $file";
        print "$syscmd\n" if ($Verbose > 0);
        system($syscmd) == 0
            or warn "$0: Can't rm $file: $!\n";
    }
    close FL;
}
elsif ($command eq "LIST") {

    # Simply print the list entries on stdout
    $syscmd = "cat $hsmfilelist";
    print "$syscmd\n" if ($Verbose > 0);
    system($syscmd) == 0
        or die "$0: Can't $syscmd: $!\n";
}


# All other commands are send to the HSM client
else {

    # Generate commands for HSM
    if ($command eq "MIGRATE") {
        $syscmd = sprintf($MigrateFormat,
                          $MigrateCommand, $VerboseOption, $hsmfilelist);
    }
    elsif ($command eq "PREMIGRATE") {
        $syscmd = sprintf($PremigrateFormat,
                          $PremigrateCommand, $VerboseOption, $hsmfilelist);
    }
    elsif ($command eq "RECALL") {
        $syscmd = sprintf($RecallFormat,
                          $RecallCommand, $VerboseOption, $hsmfilelist);
    }
    print "$syscmd\n" if ($Verbose > 0);

    # Capture both stdout & stderr from HSM command
    $syscmd .= " 2>&1 |";

    # Execute HSM command and capture the output
    open(OUT, $syscmd)
        or die "$0: Can't $syscmd: $!\n";
    while (<OUT>) {

        # Print all output if verbose
        # Print only errors if not.
        print "$_" if (($Verbose > 0) || (/$FilterOutput/));
    }
    close OUT;
}


# remove tmp file used for hsm filenames
$syscmd = "rm $hsmfilelist";
print "$syscmd\n" if ($Verbose > 0);

system($syscmd) == 0
    or warn "$0: Can't $syscmd: $!\n";


# Return success
print "$0: $command $filelist @ARGV: Ok\n", if ($Verbose > 0);
exit 0;
