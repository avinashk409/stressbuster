@echo off
echo Deploying Firestore rules...
firebase deploy --only firestore:rules
echo Deploying Firestore indexes...
firebase deploy --only firestore:indexes
echo Done!
pause 